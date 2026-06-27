-- 0174: ADR-0035 phase 4 — priority lane (separate numbering, served ahead).
-- An order can be flagged priority — requested by CS/operations, approved by admin.
-- A granted order moves to a separate 'priority' serving lane (P-n) that the now-serving
-- board serves ahead of the regular queue. This is now the ONLY way to jump the line
-- (the manual restore_serving_number is superseded).

-- 1) priority flag on the order
alter table public.job_orders add column if not exists priority_status text
  check (priority_status is null or priority_status in ('requested','granted'));

-- 2) allow the priority lane in serving_numbers
alter table public.serving_numbers drop constraint if exists serving_numbers_service_line_check;
alter table public.serving_numbers add constraint serving_numbers_service_line_check
  check (service_line in ('xray','dea','oog','other','queue','priority'));

-- 3) assign now (a) numbers ONLY the active line (submitted/processing) — so on_hold
--    orders stay out (phase 3) — and (b) routes to the order's lane (priority if granted),
--    with its own per-lane sequence + advisory lock.
create or replace function public.assign_serving_numbers(p_jo uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_week date := public.serving_week(); v_next int; v_lane text; v_status text;
begin
  if exists (select 1 from public.serving_numbers where job_order_id = p_jo and vacated_at is null) then
    return;  -- keeps an existing active number (edit / respond keeps its place)
  end if;
  select status, case when priority_status = 'granted' then 'priority' else 'queue' end
    into v_status, v_lane from public.job_orders where id = p_jo;
  if v_status is null or v_status not in ('submitted','processing') then
    return;  -- only the active line gets a number
  end if;
  perform pg_advisory_xact_lock(hashtext('serving:' || v_lane || ':' || v_week::text));
  select coalesce(max(serving_no), 0) + 1 into v_next
    from public.serving_numbers where week_start = v_week and service_line = v_lane;
  insert into public.serving_numbers (job_order_id, service_line, week_start, serving_no)
    values (p_jo, v_lane, v_week, v_next);
end;
$$;

-- 4) request priority (CS / operations) — flags the order for admin review.
create or replace function public.request_priority(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission('request_priority') then
    raise exception 'You don''t have permission to request priority.';
  end if;
  update public.job_orders set priority_status = 'requested'
    where id = p_id and status in ('submitted','processing','on_hold')
      and coalesce(priority_status, '') <> 'granted';
  if not found then raise exception 'Order not found, not open, or already prioritised.'; end if;
end;
$$;
revoke all on function public.request_priority(uuid) from public, anon;
grant execute on function public.request_priority(uuid) to authenticated;

-- 5) review priority (admin) — approve moves it to the priority lane; deny clears it.
create or replace function public.review_priority(p_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission('approve_priority') then
    raise exception 'You don''t have permission to approve priority.';
  end if;
  if p_approve then
    update public.job_orders set priority_status = 'granted' where id = p_id;
    -- move to the priority lane: drop the current (queue) number, then re-number in-lane
    update public.serving_numbers set vacated_at = now()
      where job_order_id = p_id and vacated_at is null;
    perform public.assign_serving_numbers(p_id);
  else
    update public.job_orders set priority_status = null where id = p_id;
  end if;
end;
$$;
revoke all on function public.review_priority(uuid, boolean) from public, anon;
grant execute on function public.review_priority(uuid, boolean) to authenticated;

-- 6) permissions: CS + operations request; admin approves (and can request).
insert into public.role_permissions (role, permission, allowed, updated_at) values
  ('csr','request_priority',true,now()), ('operations','request_priority',true,now()),
  ('admin','request_priority',true,now()), ('admin','approve_priority',true,now())
on conflict (role, permission) do update set allowed = excluded.allowed, updated_at = now();

notify pgrst, 'reload schema';
