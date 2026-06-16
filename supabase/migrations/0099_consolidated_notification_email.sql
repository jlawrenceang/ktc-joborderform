-- ============================================================
-- 0099 — consolidate customer emails into one "pending notification" nudge
--        (owner, 2026-06-16)
--
-- Replace the per-event emails (on_hold / rejected / payment-rejected / account
-- approved) with ONE generic, deduped email: when a customer gets a new
-- actionable notification AND has no other unread one, email "you have a
-- notification needing action — log in to view it." No details in the email
-- (security); the bell opens it after login. One nudge per unread batch — no
-- spam. Controlled by the same owner switch (emails_enabled, 0074), now ON.
-- The in-app notification bell is unchanged (it always fires).
-- ============================================================

-- 1) Retire the per-event email triggers (the functions stay, just unhooked).
drop trigger if exists on_job_order_status_email on public.job_orders;
drop trigger if exists on_broker_approved on public.customers;

-- 2) The consolidated nudge — fires on a new ACTIONABLE notification, deduped.
create or replace function public.notify_pending_email()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_email text; v_name text; v_unread int;
begin
  -- Only nudge for items that need the customer to DO something; informational
  -- kinds (serving #, completed, approved, announcement, payment confirmed) don't.
  if new.kind not in ('on_hold','rejected','payment_rejected','payment_reminder','comment','support_reply','rps','under_review') then
    return new;
  end if;
  if not public.emails_enabled() then return new; end if;
  -- Dedup: only email when this is the customer's FIRST unread notification, so
  -- there's one nudge per batch (no further email until they clear them).
  select count(*) into v_unread from public.notifications
    where customer_id = new.customer_id and read_at is null;
  if v_unread <> 1 then return new; end if;

  select email, full_name into v_email, v_name from public.customers where id = new.customer_id;
  if v_email is null then return new; end if;

  perform public.send_portal_email(
    v_email, v_name,
    'You have a notification in the KTC portal',
    'Action needed',
    'You have a notification that needs your attention in the KTC Online Portal. Please log in to view it and take action.<br/><br/>For your security the details aren''t included here — just sign in and your notifications will be waiting.',
    'https://portal.ktcterminal.com/', 'Open the portal');
  return new;
end;
$$;
drop trigger if exists notifications_pending_email on public.notifications;
create trigger notifications_pending_email after insert on public.notifications
  for each row execute function public.notify_pending_email();

-- 3) Turn customer emails ON for launch (owner decision 2026-06-16).
insert into public.app_settings (key, bool_value, updated_at) values ('emails_enabled', true, now())
on conflict (key) do update set bool_value = true, updated_at = now();
