-- ============================================================
-- 0100 — one generalized priority queue per JO (owner, 2026-06-16)
--
-- The serving number was per service line (xray/dea/oog). The owner wants ONE
-- generalized queue: every terminal-services Job Order gets a single priority
-- number ("now serving"), assigned on `submitted`, weekly reset — one queue, not
-- fragmented by service. (We can compartmentalize per-service later; for now it's
-- one queuing system.) The number lives as service_line = 'queue'.
-- ============================================================

alter table public.serving_numbers drop constraint if exists serving_numbers_service_line_check;
alter table public.serving_numbers add constraint serving_numbers_service_line_check
  check (service_line in ('xray','dea','oog','other','queue'));

-- One priority number per JO (was: one per distinct service line).
create or replace function public.assign_serving_numbers(p_jo uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_week date := public.serving_week();
  v_next int;
begin
  if exists (select 1 from public.serving_numbers
             where job_order_id = p_jo and vacated_at is null) then
    return;  -- keeps an existing active number (edit/respond keeps its place)
  end if;
  perform pg_advisory_xact_lock(hashtext('serving:queue:' || v_week::text));
  select coalesce(max(serving_no), 0) + 1 into v_next
    from public.serving_numbers where week_start = v_week;
  insert into public.serving_numbers (job_order_id, service_line, week_start, serving_no)
    values (p_jo, 'queue', v_week, v_next);
end;
$$;

-- "Now serving" board across the single queue.
create or replace function public.now_serving()
returns table (service_line text, now_serving int, last_issued int)
language sql stable security definer set search_path = public as $$
  select s.service_line,
         min(s.serving_no) filter (
           where s.vacated_at is null and jo.status in ('submitted','processing','on_hold')
         ) as now_serving,
         max(s.serving_no) as last_issued
  from public.serving_numbers s
  join public.job_orders jo on jo.id = s.job_order_id
  where s.week_start = public.serving_week()
  group by s.service_line;
$$;
