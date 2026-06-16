-- ============================================================
-- 0097 — fold RPS into the completion/release gate + ops can close DEA/OOG
--        (owner, 2026-06-16)
--
-- Audit blocker: RPS (port-services) payment ran OUTSIDE the two-gate, so an
-- order with an unpaid RPS charge could complete, show PAID on the verify QR,
-- and be released. Now "ready" = all services done AND base payment confirmed
-- AND (RPS not needed OR RPS payment confirmed). Applied consistently in
-- jo_ready_to_complete, the auto-complete trigger (now also fires when the RPS
-- payment is confirmed last), the raw-update backstop, and staff_transition_order;
-- verify_job_order returns RPS state so the slip's PAID badge reflects it.
--
-- Also: operations regains process_job_orders so it can mark DEA/OOG services
-- done and close the non-X-ray orders it accepts (the floor bottleneck). X-ray
-- stays checker-only (0095, unaffected — that branch needs confirm_xray).
-- ============================================================

update public.role_permissions set allowed = true
  where role = 'operations' and permission = 'process_job_orders';

-- ---------- the unified release/completion readiness ----------
create or replace function public.jo_ready_to_complete(p_jo uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.jo_all_services_done(p_jo)
     and (select jo.payment_status = 'confirmed'
                 and (jo.rps_status <> 'needed' or jo.rps_payment_status = 'confirmed')
          from public.job_orders jo where jo.id = p_jo);
$$;

-- ---------- auto-complete when the LAST payment (base or RPS) is confirmed ----------
create or replace function public.complete_on_payment_confirmed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('submitted','processing','on_hold')
     and public.jo_all_services_done(new.id)
     and new.payment_status = 'confirmed'
     and (new.rps_status <> 'needed' or new.rps_payment_status = 'confirmed')
     and ((new.payment_status = 'confirmed' and old.payment_status is distinct from 'confirmed')
          or (new.rps_payment_status = 'confirmed' and old.rps_payment_status is distinct from 'confirmed')) then
    new.status := 'completed';
    new.completed_at := coalesce(new.completed_at, now());
  end if;
  return new;
end;
$$;
drop trigger if exists job_orders_complete_on_payment on public.job_orders;
create trigger job_orders_complete_on_payment
  before update of payment_status, rps_payment_status on public.job_orders
  for each row execute function public.complete_on_payment_confirmed();

-- ---------- raw-update backstop (0094) now includes RPS ----------
create or replace function public.enforce_two_gate_complete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    if not (public.jo_all_services_done(new.id)
            and new.payment_status = 'confirmed'
            and (new.rps_status <> 'needed' or new.rps_payment_status = 'confirmed')) then
      raise exception 'Cannot complete — every service done, base payment, and any RPS charge must all be cleared.'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

-- ---------- staff_transition_order: complete branch uses jo_ready_to_complete ----------
create or replace function public.staff_transition_order(
  p_id          uuid,
  p_status      text,
  p_note        text    default null,
  p_recoverable boolean default null
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cur  text;
  v_gate text := case p_status
    when 'processing' then 'accept_orders'
    when 'completed'  then 'complete_orders'
    when 'on_hold'    then 'hold_reject_orders'
    when 'rejected'   then 'hold_reject_orders'
    else null end;
begin
  if v_gate is null then
    raise exception 'Unsupported transition to %.', p_status;
  end if;
  if not public.has_permission(v_gate) then
    raise exception 'You don''t have permission for this action.';
  end if;

  select status into v_cur from public.job_orders where id = p_id for update;
  if not found then raise exception 'Job order not found.'; end if;

  if p_status = 'processing' and v_cur not in ('submitted','on_hold') then
    raise exception 'Only a submitted or on-hold order can be accepted.';
  elsif p_status in ('on_hold','rejected') and v_cur not in ('submitted','processing','on_hold') then
    raise exception 'This order can''t be held or rejected now.';
  elsif p_status = 'completed' then
    if v_cur not in ('submitted','processing','on_hold') then
      raise exception 'Only an open order can be completed.';
    end if;
    if not public.jo_ready_to_complete(p_id) then
      raise exception 'Can''t complete yet — every service, the base payment, and any RPS charge must all be cleared.';
    end if;
  end if;

  update public.job_orders
  set status = p_status,
      admin_note = coalesce(p_note, admin_note),
      rejected_recoverable = case when p_status = 'rejected'
        then coalesce(p_recoverable, rejected_recoverable) else rejected_recoverable end
  where id = p_id;
end;
$$;
revoke all on function public.staff_transition_order(uuid, text, text, boolean) from public, anon;
grant execute on function public.staff_transition_order(uuid, text, text, boolean) to authenticated;

-- ---------- verify RPC returns RPS state (so the slip PAID badge reflects it) ----------
drop function if exists public.verify_job_order(uuid);
create function public.verify_job_order(p_id uuid)
returns table (
  jo_number      text,
  status         text,
  payment_status text,
  rps_status     text,
  rps_payment_status text,
  completed_at   timestamptz,
  consignee      text,
  containers     text[]
)
language sql security definer set search_path = public as $$
  select jo.jo_number, jo.status, jo.payment_status, jo.rps_status, jo.rps_payment_status,
         jo.completed_at,
         (select c.code || ' – ' || c.name from public.consignees c where c.id = jo.consignee_id),
         (select array_agg(l.container_number order by l.container_number)
            from public.job_order_lines l where l.job_order_id = jo.id)
  from public.job_orders jo
  where jo.id = p_id;
$$;
revoke all on function public.verify_job_order(uuid) from public;
grant execute on function public.verify_job_order(uuid) to anon, authenticated;
