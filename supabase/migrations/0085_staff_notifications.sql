-- ============================================================
-- 0085 — staff notifications (owner, 2026-06-16)
--
-- The mirror of the customer notification bell (0071), but for KTC STAFF and
-- routed BY PERMISSION instead of by owner. A single shared notification row
-- carries a `required_permission`; RLS exposes it only to staff who hold that
-- gate via has_permission(), so each role sees only the alerts it can act on
-- (a cashier sees 'review_payments', support staff see 'manage_support', the
-- approvals desk sees 'manage_approvals'; owner passes every gate). Read state
-- is tracked per staff member in a separate reads table (the 0077 pattern), so
-- one row is never fanned out per recipient.
--
-- Triggers/RPC write (SECURITY DEFINER); staff only ever SELECT.
-- ============================================================

-- ---------- shared notification rows ----------
create table if not exists public.staff_notifications (
  id                  uuid primary key default gen_random_uuid(),
  required_permission text not null,            -- the has_permission() gate that may see this
  kind                text not null,            -- payment|rps_payment|support|account
  title               text not null,
  job_order_id        uuid references public.job_orders(id) on delete cascade,
  ticket_id           uuid references public.support_tickets(id) on delete cascade,
  created_at          timestamptz not null default now()
);
create index if not exists staff_notifications_created_idx
  on public.staff_notifications (created_at desc);

-- ---------- per-staff read tracking (0077 pattern) ----------
create table if not exists public.staff_notification_reads (
  staff_uid       uuid not null,
  notification_id uuid not null references public.staff_notifications(id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (staff_uid, notification_id)
);

-- ---------- RLS ----------
alter table public.staff_notifications      enable row level security;
alter table public.staff_notification_reads enable row level security;

-- A staff member sees a notification only if they hold its gate. Owner passes
-- every gate via has_permission(). Writes go through the definer helper only.
drop policy if exists "read permitted staff notifications" on public.staff_notifications;
create policy "read permitted staff notifications" on public.staff_notifications
  for select to authenticated
  using (public.has_permission(required_permission));

-- Each staff member reads/writes only their own read markers.
drop policy if exists "read own staff notif reads" on public.staff_notification_reads;
create policy "read own staff notif reads" on public.staff_notification_reads
  for select to authenticated using (staff_uid = auth.uid());

drop policy if exists "insert own staff notif reads" on public.staff_notification_reads;
create policy "insert own staff notif reads" on public.staff_notification_reads
  for insert to authenticated with check (staff_uid = auth.uid());

drop policy if exists "delete own staff notif reads" on public.staff_notification_reads;
create policy "delete own staff notif reads" on public.staff_notification_reads
  for delete to authenticated using (staff_uid = auth.uid());

-- ---------- writer helper (internal; triggers only) ----------
create or replace function public.notify_staff(
  p_perm   text,
  p_kind   text,
  p_title  text,
  p_jo     uuid default null,
  p_ticket uuid default null
)
returns void language sql security definer set search_path = public as $$
  insert into public.staff_notifications (required_permission, kind, title, job_order_id, ticket_id)
  values (p_perm, p_kind, p_title, p_jo, p_ticket);
$$;
revoke all on function public.notify_staff(text, text, text, uuid, uuid) from public, anon;

-- ---------- mark read ----------
-- Insert read markers for the caller across every notification they're allowed
-- to see (or just the given ids). Idempotent.
create or replace function public.mark_staff_notifications_read(p_ids uuid[] default null)
returns void language sql security definer set search_path = public as $$
  insert into public.staff_notification_reads (staff_uid, notification_id)
  select auth.uid(), sn.id
  from public.staff_notifications sn
  where public.has_permission(sn.required_permission)
    and (p_ids is null or sn.id = any(p_ids))
  on conflict do nothing;
$$;
revoke all on function public.mark_staff_notifications_read(uuid[]) from public, anon;
grant execute on function public.mark_staff_notifications_read(uuid[]) to authenticated;

-- ============================================================
-- Triggers that raise staff notifications
-- ============================================================

-- 1) Payment proof submitted (regular + RPS) → the payments desk.
create or replace function public.notify_staff_payment()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_label text := coalesce(new.jo_number, nullif(new.entry_number, ''), 'an order');
begin
  if new.payment_status = 'submitted' and old.payment_status is distinct from 'submitted' then
    perform public.notify_staff(
      'review_payments', 'payment',
      'Payment proof uploaded for ' || v_label, new.id, null);
  end if;
  if new.rps_payment_status = 'submitted' and old.rps_payment_status is distinct from 'submitted' then
    perform public.notify_staff(
      'review_payments', 'rps_payment',
      'RPS payment uploaded for ' || v_label, new.id, null);
  end if;
  return new;
end;
$$;
drop trigger if exists job_orders_notify_staff_payment on public.job_orders;
create trigger job_orders_notify_staff_payment after update on public.job_orders
  for each row execute function public.notify_staff_payment();

-- 2) Customer support activity (new ticket / customer reply) → the support inbox.
create or replace function public.notify_staff_support()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_staff = false then
    perform public.notify_staff(
      'manage_support', 'support',
      'New support message on a ticket', null, new.ticket_id);
  end if;
  return new;
end;
$$;
drop trigger if exists support_messages_notify_staff on public.support_messages;
create trigger support_messages_notify_staff after insert on public.support_messages
  for each row execute function public.notify_staff_support();

-- 3) Account submitted its valid ID → the approvals desk.
create or replace function public.notify_staff_account()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.valid_id_path is not null and old.valid_id_path is null and new.status = 'pending' then
    perform public.notify_staff(
      'manage_approvals', 'account',
      'New account awaiting verification: ' || coalesce(new.full_name, ''), null, null);
  end if;
  return new;
end;
$$;
drop trigger if exists customers_notify_staff_account on public.customers;
create trigger customers_notify_staff_account after update on public.customers
  for each row execute function public.notify_staff_account();
