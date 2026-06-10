-- ============================================================
-- 0031 — close the order-cap race in enforce_order_caps.
--
-- The cap check was count-then-insert: two concurrent inserts by the same
-- customer could both see count=9 and both commit, exceeding the cap of 10.
-- Fix: take a per-customer transaction-scoped advisory lock before counting,
-- serializing cap checks for that customer (other customers are unaffected;
-- the lock releases automatically at commit/rollback).
-- Logic is otherwise identical to 0029's definition.
-- ============================================================

create or replace function public.enforce_order_caps()
returns trigger language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  if new.status in ('held','submitted','processing','on_hold') then
    perform pg_advisory_xact_lock(hashtext('jo_caps:' || new.customer_id::text));
  end if;
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
