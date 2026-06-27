-- 0175: ADR-0035 phase 5 — re-X-ray lane.
-- A blurred X-ray on a COMPLETED order: checker/ops request a re-X-ray, admin approves.
-- It's a CHILD job order — same customer/consignee/vessel/containers, a suffixed number
-- (JO-000001A, B…), is_rexray=true — that rides its own 'rexray' serving lane and runs
-- its own little lifecycle. Free now (rexray_billable defaults false; a free re-X-ray
-- completes on services-done with no payment gate), billable-capable for the future.

-- 1) columns
alter table public.job_orders
  add column if not exists parent_job_order_id uuid references public.job_orders(id),
  add column if not exists is_rexray       boolean not null default false,
  add column if not exists rexray_billable boolean not null default false,
  add column if not exists rexray_status   text check (rexray_status in ('requested','approved'));

-- 2) allow the re-X-ray serving lane
alter table public.serving_numbers drop constraint if exists serving_numbers_service_line_check;
alter table public.serving_numbers add constraint serving_numbers_service_line_check
  check (service_line in ('xray','dea','oog','other','queue','priority','rexray'));

-- 3) assign routes is_rexray → 'rexray' lane, and a re-X-ray child gets NO number until
--    the admin approves it (rexray_status='approved').
create or replace function public.assign_serving_numbers(p_jo uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_week date := public.serving_week(); v_next int; v_lane text; v_status text;
        v_is_rexray boolean; v_rexray_status text;
begin
  if exists (select 1 from public.serving_numbers where job_order_id = p_jo and vacated_at is null) then
    return;
  end if;
  select status, is_rexray, rexray_status,
         case when is_rexray then 'rexray'
              when priority_status = 'granted' then 'priority'
              else 'queue' end
    into v_status, v_is_rexray, v_rexray_status, v_lane
    from public.job_orders where id = p_jo;
  if v_status is null or v_status not in ('submitted','processing') then return; end if;
  if v_is_rexray and coalesce(v_rexray_status, '') <> 'approved' then return; end if;  -- not in line until approved
  perform pg_advisory_xact_lock(hashtext('serving:' || v_lane || ':' || v_week::text));
  select coalesce(max(serving_no), 0) + 1 into v_next
    from public.serving_numbers where week_start = v_week and service_line = v_lane;
  insert into public.serving_numbers (job_order_id, service_line, week_start, serving_no)
    values (p_jo, v_lane, v_week, v_next);
end;
$$;

-- 4) re-X-ray children are KTC-initiated — they don't count toward the customer cap.
create or replace function public.enforce_order_caps()
returns trigger language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  if new.is_rexray then return new; end if;
  if auth.uid() is not null and public.has_permission('file_job_orders') then return new; end if;
  if new.status in ('held','submitted','processing','on_hold') then
    perform pg_advisory_xact_lock(hashtext('jo_caps:' || new.customer_id::text));
  end if;
  if new.status = 'held' then
    select count(*) into cnt from public.job_orders where customer_id = new.customer_id and status = 'held';
    if cnt >= 10 then
      raise exception 'You can keep at most 10 job orders on hold until your account is verified. Upload your valid ID to get verified.'
        using errcode = 'check_violation';
    end if;
  elsif new.status in ('submitted','processing','on_hold') then
    select count(*) into cnt from public.job_orders
      where customer_id = new.customer_id and status in ('submitted','processing','on_hold') and not is_rexray;
    if cnt >= 10 then
      raise exception 'You have 10 open job orders — contact KTC admin to file more.'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

-- 5) a FREE re-X-ray completes on services-done alone (no payment gate).
create or replace function public.jo_ready_to_complete(p_jo uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.jo_all_services_done(p_jo)
     and (select case
                   when jo.is_rexray and not jo.rexray_billable then true
                   else jo.payment_status = 'confirmed'
                        and (jo.rps_status <> 'needed' or jo.rps_payment_status = 'confirmed')
                 end
          from public.job_orders jo where jo.id = p_jo);
$$;

-- 6) request a re-X-ray (checker / ops) — builds the suffixed child + copies the containers.
create or replace function public.request_rexray(p_parent uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_p record; v_n int; v_child uuid;
begin
  if not public.has_permission('request_rexray') then
    raise exception 'You don''t have permission to request a re-X-ray.';
  end if;
  select * into v_p from public.job_orders where id = p_parent;
  if not found then raise exception 'Order not found.'; end if;
  if v_p.is_rexray then raise exception 'Can''t re-X-ray a re-X-ray.'; end if;
  if v_p.status <> 'completed' then raise exception 'Re-X-ray is only for a completed order.'; end if;
  select count(*) into v_n from public.job_orders where parent_job_order_id = p_parent;
  insert into public.job_orders (customer_id, consignee_id, entry_number, vessel_visit, vessel_name,
                                 voyage_number, status, jo_number, is_rexray, parent_job_order_id,
                                 rexray_status, rexray_billable)
  values (v_p.customer_id, v_p.consignee_id, v_p.entry_number, v_p.vessel_visit, v_p.vessel_name,
          v_p.voyage_number, 'submitted', coalesce(v_p.jo_number, '') || chr(65 + v_n), true, p_parent,
          'requested', false)
  returning id into v_child;
  insert into public.job_order_lines (job_order_id, container_number, service_request, size, fill, kind)
  select v_child, container_number, service_request, size, fill, kind
    from public.job_order_lines where job_order_id = p_parent;
  return v_child;
end;
$$;
revoke all on function public.request_rexray(uuid) from public, anon;
grant execute on function public.request_rexray(uuid) to authenticated;

-- 7) review a re-X-ray (admin) — approve puts it in the re-X-ray queue; deny cancels it.
create or replace function public.review_rexray(p_id uuid, p_approve boolean, p_billable boolean default false)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission('approve_rexray') then
    raise exception 'You don''t have permission to approve a re-X-ray.';
  end if;
  if p_approve then
    update public.job_orders
       set rexray_status = 'approved', rexray_billable = coalesce(p_billable, false), status = 'processing'
     where id = p_id and is_rexray and rexray_status = 'requested';
  else
    update public.job_orders set status = 'cancelled'
     where id = p_id and is_rexray and rexray_status = 'requested';
  end if;
  if not found then raise exception 'Re-X-ray request not found.'; end if;
end;
$$;
revoke all on function public.review_rexray(uuid, boolean, boolean) from public, anon;
grant execute on function public.review_rexray(uuid, boolean, boolean) to authenticated;

-- 8) permissions: checker + operations request; admin approves.
insert into public.role_permissions (role, permission, allowed, updated_at) values
  ('checker','request_rexray',true,now()), ('operations','request_rexray',true,now()),
  ('admin','request_rexray',true,now()), ('admin','approve_rexray',true,now())
on conflict (role, permission) do update set allowed = excluded.allowed, updated_at = now();

notify pgrst, 'reload schema';
