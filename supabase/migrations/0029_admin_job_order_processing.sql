-- ============================================================
-- 0029 — admin job-order processing workflow.
--
-- "Approve = start processing": an admin advances a submitted order through
-- submitted -> processing -> completed. 'processing' counts as APPROVED and
-- unlocks the printable slip. The admin can also put an order ON HOLD (needs
-- info from the customer) or REJECT it, leaving a customer-visible note.
-- Customers still cannot UPDATE their orders (no self-processing).
--
--   status flow (admin):
--     submitted  -> processing | on_hold | rejected
--     processing -> completed  | on_hold | rejected
--     on_hold    -> processing | rejected
-- (UI enforces the sensible transitions; RLS just lets admins update.)
-- ============================================================

-- 1) Two new statuses: on_hold (admin needs info) + rejected (admin declined).
--    NOTE: 'held' stays reserved for not-yet-verified customers (queue-hidden);
--    admin "hold for info" is the distinct 'on_hold'.
alter table public.job_orders drop constraint if exists job_orders_status_check;
alter table public.job_orders add constraint job_orders_status_check
  check (status in ('held','submitted','processing','completed','cancelled','on_hold','rejected'));

-- 2) Customer-visible admin note (why on hold / rejected / what to update).
alter table public.job_orders add column if not exists admin_note text;

-- 3) Admins (incl. owner — is_admin() returns is_admin OR is_owner) may update
--    any job order. Mirrors the existing "admin updates ..." policies.
drop policy if exists "admin updates job orders" on public.job_orders;
create policy "admin updates job orders" on public.job_orders
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 4) Count on_hold toward a customer's open-order slots — it's still an active
--    order occupying a slot (only completed/cancelled/rejected free one).
create or replace function public.enforce_order_caps()
returns trigger language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  if new.status = 'held' then
    select count(*) into cnt from public.job_orders
      where customer_id = new.customer_id and status = 'held';
    if cnt >= 10 then
      raise exception 'You can keep at most 10 job orders on hold until your account is verified. Upload your valid ID to get verified.'
        using errcode = 'check_violation';
    end if;
  elsif new.status in ('submitted','processing','on_hold') then
    select count(*) into cnt from public.job_orders
      where customer_id = new.customer_id and status in ('submitted','processing','on_hold');
    if cnt >= 10 then
      raise exception 'You have 10 open job orders — contact KTC admin to file more.'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;
