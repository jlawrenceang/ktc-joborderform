-- ============================================================
-- 0084 — serving-number + payment-reminder notifications (owner, 2026-06-16)
--
-- Closes the two remaining notification gaps:
--   * serving-number assigned → tell the customer their queue position
--   * payment reminder → a gentle daily nudge for accepted-but-unpaid orders
--
-- In-app only (fire regardless of the owner email switch). The payment reminder
-- is capped to once every 3 days per order and only after it's been accepted
-- (processing) + still unpaid for 2+ days, so it never spams.
-- ============================================================

-- 1) Serving number assigned → notify the order's customer of its line position.
create or replace function public.notify_serving_assigned()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_cust  uuid;
  v_label text;
begin
  select customer_id, coalesce(jo_number, nullif(entry_number, ''), 'your job order')
    into v_cust, v_label
  from public.job_orders where id = new.job_order_id;
  if v_cust is not null then
    insert into public.notifications (customer_id, job_order_id, kind, title)
    values (v_cust, new.job_order_id, 'serving',
            'Serving number for ' || v_label || ' (' || new.service_line || ' line): #' || new.serving_no);
  end if;
  return new;
end;
$$;
drop trigger if exists serving_numbers_notify on public.serving_numbers;
create trigger serving_numbers_notify after insert on public.serving_numbers
  for each row execute function public.notify_serving_assigned();

-- 2) Payment reminder — daily sweep.
alter table public.job_orders add column if not exists payment_reminded_at timestamptz;

create or replace function public.remind_unpaid_orders()
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  with due as (
    update public.job_orders jo
       set payment_reminded_at = now()
     where jo.status = 'processing'
       and jo.payment_status = 'unpaid'
       and jo.created_at < now() - interval '2 days'
       and (jo.payment_reminded_at is null or jo.payment_reminded_at < now() - interval '3 days')
    returning jo.id, jo.customer_id,
              coalesce(jo.jo_number, nullif(jo.entry_number, ''), 'your job order') as label
  ),
  ins as (
    insert into public.notifications (customer_id, job_order_id, kind, title)
    select customer_id, id, 'payment_reminder',
           'Reminder: ' || label || ' is awaiting payment. Upload your payment slip to speed up processing.'
    from due
    returning 1
  )
  select count(*) into n from ins;
  return n;
end;
$$;
revoke all on function public.remind_unpaid_orders() from public, anon;

-- Daily at 01:00 (server time). Idempotent (re)schedule.
do $$
begin
  perform cron.unschedule('remind-unpaid-orders');
exception when others then null;
end $$;
select cron.schedule('remind-unpaid-orders', '0 1 * * *', $$ select public.remind_unpaid_orders(); $$);
