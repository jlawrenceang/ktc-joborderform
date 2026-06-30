-- 0228 — go-live hardening (codex review fixes)
--
-- A. P1 — release charges are parent-aware in the customer pay path.
--    submit_charge_payment authorized only through job_orders, so a release
--    charge (job_order_id NULL, release_order_id set) could never be paid by the
--    customer even though create_payment_order / confirm_charge_payment /
--    confirm_payment_order were already made parent-aware in 0215. This closes
--    the one remaining per-charge submit gap so release charges flow through the
--    same spine as JO charges (decided 2026-06-30).
--
-- B. P3 — container cap raised 100 -> 200 to match the filing UI (a C-entry can
--    run 150–200 vans; ContainerLinesEditor was built for that range while the
--    backend rejected >100). Applied to file_job_order, admin_file_job_order, and
--    update_job_order (the last had NO upper cap at all — added here).
--
-- Each function below is the CURRENT live body (file_job_order/admin_file_job_order
-- from 0212, update_job_order from 0222 — the latest of each), reproduced verbatim
-- with ONLY the cap threshold changed and the cap added to update_job_order.

-- ============================================================================
-- A. submit_charge_payment — parent-aware (job_orders OR release_orders)
-- ============================================================================
create or replace function public.submit_charge_payment(p_charge uuid, p_proof text)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare v_cust uuid := public.current_broker_id();
begin
  update public.charges c
     set payment_status = 'submitted', payment_proof_path = nullif(p_proof,''), payment_submitted_at = now(), payment_note = null
   where c.id = p_charge and c.bill_status = 'billed' and c.payment_status in ('unpaid','rejected')
     and c.payment_order_id is null
     and (
       exists (select 1 from public.job_orders j where j.id = c.job_order_id and j.customer_id = v_cust)
       or exists (select 1 from public.release_orders r where r.id = c.release_order_id and r.customer_id = v_cust)
     );
  if not found then raise exception 'This charge is not awaiting your payment.'; end if;
  perform public.log_charge_audit(p_charge, 'payment_submitted', null);
end;
$function$;

-- ============================================================================
-- B1. file_job_order — cap 100 -> 200 (0212 body, verbatim except the cap)
-- ============================================================================
create or replace function public.file_job_order(
  p_consignee uuid, p_entry_number text, p_vessel_visit text,
  p_vessel_name text, p_voyage_number text, p_lines jsonb
)
returns uuid language plpgsql security definer set search_path = 'public' as $function$
declare
  v_cust   uuid := public.current_broker_id();
  v_status text;
  v_jo     uuid;
  v_count  int := 0;
  e        jsonb;
begin
  if v_cust is null then raise exception 'No customer profile found.'; end if;
  if not public.broker_is_approved() then
    raise exception 'Your account can''t file orders right now.';
  end if;
  if not public.has_recorded_consent() then
    raise exception 'Please accept the Customer Agreement before filing a job order.';
  end if;
  if p_consignee is null or not exists (select 1 from public.consignees where id = p_consignee) then
    raise exception 'Select a consignee.' using errcode = 'check_violation';
  end if;
  if length(coalesce(trim(p_entry_number), '')) = 0 then
    raise exception 'Enter the Entry Number (C-…).' using errcode = 'check_violation';
  end if;
  -- KTC-21: header length caps.
  if length(trim(p_entry_number)) > 40 then
    raise exception 'Entry Number is too long (max 40 characters).' using errcode = 'check_violation';
  end if;
  if coalesce(nullif(trim(p_vessel_name), ''), '') = ''
     or coalesce(nullif(trim(p_voyage_number), ''), '') = '' then
    raise exception 'Enter the vessel name and voyage number.' using errcode = 'check_violation';
  end if;
  if length(trim(p_vessel_name)) > 80 then
    raise exception 'Vessel name is too long (max 80 characters).' using errcode = 'check_violation';
  end if;
  if length(trim(p_voyage_number)) > 80 then
    raise exception 'Voyage number is too long (max 80 characters).' using errcode = 'check_violation';
  end if;
  -- KTC-22: reject a malformed (non-array) p_lines with a friendly message.
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'Add at least one container.' using errcode = 'check_violation';
  end if;
  for e in select * from jsonb_array_elements(p_lines) loop
    if length(coalesce(trim(e->>'container_number'), '')) > 0 then
      v_count := v_count + 1;
      -- KTC-22: container number must be alphanumeric, reasonable length.
      if upper(trim(e->>'container_number')) !~ '^[A-Z0-9-]{4,20}$' then
        raise exception 'Container number "%" looks invalid — use 4–20 letters or digits.', trim(e->>'container_number')
          using errcode = 'check_violation';
      end if;
      -- KTC-09: only catalogued, active services may be filed.
      if not exists (select 1 from public.service_rates r where r.service = e->>'service_request' and r.active) then
        raise exception 'Unknown service "%". Please pick a service from the list.', coalesce(e->>'service_request', '')
          using errcode = 'check_violation';
      end if;
      -- KTC-22: friendly messages for size/fill/kind (table CHECKs stay as backstop).
      if coalesce(nullif(trim(e->>'size'), ''), '20') not in ('20','40') then
        raise exception 'Pick a valid container size (20 or 40).' using errcode = 'check_violation';
      end if;
      if coalesce(nullif(trim(e->>'fill'), ''), 'full') not in ('empty','full') then
        raise exception 'Pick a valid load (empty or full).' using errcode = 'check_violation';
      end if;
      if coalesce(nullif(trim(e->>'kind'), ''), 'dry') not in ('dry','reefer') then
        raise exception 'Pick a valid container type (dry or reefer).' using errcode = 'check_violation';
      end if;
    end if;
  end loop;
  if v_count = 0 then
    raise exception 'Add at least one container.' using errcode = 'check_violation';
  end if;
  -- KTC-08: cap the order size (mirrors admin_file_job_order). 0228: 100 -> 200.
  if v_count > 200 then
    raise exception 'A job order can have at most 200 containers.' using errcode = 'check_violation';
  end if;

  v_status := case when public.broker_is_approved() then 'submitted' else 'held' end;

  insert into public.job_orders (customer_id, consignee_id, entry_number, vessel_visit, vessel_name, voyage_number, status)
  values (v_cust, p_consignee, upper(trim(p_entry_number)), nullif(trim(p_vessel_visit), ''),
          upper(trim(p_vessel_name)), upper(trim(p_voyage_number)), v_status)
  returning id into v_jo;

  insert into public.job_order_lines (job_order_id, container_number, service_request, size, fill, kind)
  select v_jo, upper(trim(j->>'container_number')), j->>'service_request',
         nullif(trim(coalesce(j->>'size', '')), ''), nullif(trim(coalesce(j->>'fill', '')), ''), nullif(trim(coalesce(j->>'kind', '')), '')
  from jsonb_array_elements(p_lines) j
  where length(coalesce(trim(j->>'container_number'), '')) > 0;

  -- 0212: seed container identity + the base service charge(s) (additive).
  perform public.seed_job_order_billing(v_jo);

  return v_jo;
end;
$function$;
revoke all on function public.file_job_order(uuid, text, text, text, text, jsonb) from public, anon;
grant execute on function public.file_job_order(uuid, text, text, text, text, jsonb) to authenticated;

-- ============================================================================
-- B2. admin_file_job_order — cap 100 -> 200 (0212 body, verbatim except the cap)
-- ============================================================================
create or replace function public.admin_file_job_order(
  p_customer_id uuid, p_consignee_id uuid, p_entry_number text, p_lines jsonb,
  p_vessel_visit text default null, p_vessel_name text default null, p_voyage_number text default null
)
returns jsonb language plpgsql security definer set search_path = 'public' as $function$
declare
  v_customer record;
  v_id uuid;
  v_jo text;
  v_line jsonb;
  v_container text;
  v_service text;
  v_count int := 0;
begin
  if not public.has_permission('file_job_orders') then
    raise exception 'You don''t have permission to file job orders on behalf of customers.';
  end if;

  select id, full_name, status, staff_role into v_customer
    from public.customers where id = p_customer_id;
  if not found then raise exception 'Customer not found.'; end if;
  if v_customer.staff_role is not null then
    raise exception 'That account is a staff account — pick a customer.';
  end if;
  if v_customer.status not in ('approved', 'pending') then
    raise exception 'This customer''s account is % — job orders can''t be filed for it.', v_customer.status;
  end if;

  if not exists (select 1 from public.consignees where id = p_consignee_id) then
    raise exception 'Consignee not found.';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'Add at least one container.' using errcode = 'check_violation';
  end if;
  -- 0228: cap raised 100 -> 200.
  if jsonb_array_length(p_lines) > 200 then
    raise exception 'A job order can have at most 200 containers.' using errcode = 'check_violation';
  end if;

  insert into public.job_orders (customer_id, consignee_id, entry_number, status, vessel_visit, vessel_name, voyage_number)
  values (p_customer_id, p_consignee_id, nullif(trim(coalesce(p_entry_number, '')), ''), 'submitted',
          nullif(trim(coalesce(p_vessel_visit, '')), ''),
          nullif(trim(coalesce(p_vessel_name, '')), ''),
          nullif(trim(coalesce(p_voyage_number, '')), ''))
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_container := upper(trim(coalesce(v_line->>'container_number', '')));
    v_service   := trim(coalesce(v_line->>'service_request', ''));
    if v_container = '' then continue; end if;
    if length(v_container) > 30 or length(v_service) > 80 or v_service = '' then
      raise exception 'Invalid container line.' using errcode = 'check_violation';
    end if;
    -- KTC-09: only catalogued, active services may be filed.
    if not exists (select 1 from public.service_rates r where r.service = v_service and r.active) then
      raise exception 'Unknown service "%". Please pick a service from the list.', v_service using errcode = 'check_violation';
    end if;
    insert into public.job_order_lines (job_order_id, container_number, service_request, size, fill, kind)
    values (v_id, v_container, v_service,
            nullif(trim(coalesce(v_line->>'size', '')), ''), nullif(trim(coalesce(v_line->>'fill', '')), ''), nullif(trim(coalesce(v_line->>'kind', '')), ''));
    v_count := v_count + 1;
  end loop;
  if v_count = 0 then
    raise exception 'Add at least one container.' using errcode = 'check_violation';
  end if;

  -- 0212: seed container identity + the base service charge(s) (additive).
  perform public.seed_job_order_billing(v_id);

  select jo_number into v_jo from public.job_orders where id = v_id;
  return jsonb_build_object('id', v_id, 'jo_number', v_jo, 'customer_name', v_customer.full_name);
end;
$function$;
revoke all on function public.admin_file_job_order(uuid, uuid, text, jsonb, text, text, text) from public, anon;
grant execute on function public.admin_file_job_order(uuid, uuid, text, jsonb, text, text, text) to authenticated;

-- ============================================================================
-- B3. update_job_order — add the missing cap (0222 body, verbatim + cap 200)
-- ============================================================================
create or replace function public.update_job_order(
  p_id uuid, p_consignee_id uuid, p_entry_number text,
  p_vessel_visit text, p_vessel_name text, p_voyage_number text, p_lines jsonb
)
returns void language plpgsql security definer set search_path = 'public' as $function$
declare
  v_row   public.job_orders%rowtype;
  v_count int := 0;
  e       jsonb;
begin
  select * into v_row from public.job_orders
    where id = p_id and customer_id = public.current_broker_id() for update;
  if not found then raise exception 'Job order not found.'; end if;
  if coalesce(v_row.is_rexray, false) then
    raise exception 'This is an internal KTC re-X-ray and can''t be edited here.';
  end if;
  if v_row.status not in ('held', 'submitted') then
    raise exception 'This order can''t be edited anymore — KTC has accepted it. Reply on an on-hold order, or contact KTC admin.';
  end if;
  -- 0222 (Jarvis F2): once billing has moved, editing would under-bill the new lines.
  if exists (select 1 from public.charges c
             where c.job_order_id = p_id
               and (c.payment_status <> 'unpaid' or c.invoice_state <> 'draft' or c.payment_order_id is not null)) then
    raise exception 'This order already has billing in progress — please contact KTC admin to change it.'
      using errcode = 'check_violation';
  end if;
  if p_consignee_id is null then
    raise exception 'Select a consignee.' using errcode = 'check_violation';
  end if;
  if not exists (select 1 from public.consignees where id = p_consignee_id) then
    raise exception 'Consignee not found.';
  end if;
  if length(coalesce(trim(p_entry_number), '')) = 0 then
    raise exception 'Enter the Entry Number (C-…).' using errcode = 'check_violation';
  end if;
  if length(trim(p_entry_number)) > 40 then
    raise exception 'Entry Number is too long (max 40 characters).' using errcode = 'check_violation';
  end if;
  if coalesce(nullif(trim(p_vessel_name), ''), '') = ''
     or coalesce(nullif(trim(p_voyage_number), ''), '') = '' then
    raise exception 'Enter the vessel name and voyage number.' using errcode = 'check_violation';
  end if;
  if length(trim(p_vessel_name)) > 80 then
    raise exception 'Vessel name is too long (max 80 characters).' using errcode = 'check_violation';
  end if;
  if length(trim(p_voyage_number)) > 80 then
    raise exception 'Voyage number is too long (max 80 characters).' using errcode = 'check_violation';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'Add at least one container.' using errcode = 'check_violation';
  end if;
  for e in select * from jsonb_array_elements(p_lines) loop
    if length(coalesce(trim(e->>'container_number'), '')) > 0 then
      v_count := v_count + 1;
      if upper(trim(e->>'container_number')) !~ '^[A-Z0-9-]{4,20}$' then
        raise exception 'Container number "%" looks invalid — use 4–20 letters or digits.', trim(e->>'container_number')
          using errcode = 'check_violation';
      end if;
      if not exists (select 1 from public.service_rates r where r.service = e->>'service_request' and r.active) then
        raise exception 'Unknown service "%". Please pick a service from the list.', coalesce(e->>'service_request', '')
          using errcode = 'check_violation';
      end if;
      if coalesce(nullif(trim(e->>'size'), ''), '20') not in ('20','40') then
        raise exception 'Pick a valid container size (20 or 40).' using errcode = 'check_violation';
      end if;
      if coalesce(nullif(trim(e->>'fill'), ''), 'full') not in ('empty','full') then
        raise exception 'Pick a valid load (empty or full).' using errcode = 'check_violation';
      end if;
      if coalesce(nullif(trim(e->>'kind'), ''), 'dry') not in ('dry','reefer') then
        raise exception 'Pick a valid container type (dry or reefer).' using errcode = 'check_violation';
      end if;
    end if;
  end loop;
  if v_count = 0 then
    raise exception 'Add at least one container.' using errcode = 'check_violation';
  end if;
  -- 0228: cap edits to match filing (was missing here; mirrors file_job_order's 200).
  if v_count > 200 then
    raise exception 'A job order can have at most 200 containers.' using errcode = 'check_violation';
  end if;
  update public.job_orders
  set consignee_id  = p_consignee_id,
      entry_number  = upper(trim(p_entry_number)),
      vessel_visit  = nullif(trim(p_vessel_visit), ''),
      vessel_name   = upper(trim(p_vessel_name)),
      voyage_number = upper(trim(p_voyage_number)),
      last_customer_edit_at = case when v_row.status = 'submitted' then now() else last_customer_edit_at end
  where id = p_id;
  delete from public.job_order_lines where job_order_id = p_id;
  insert into public.job_order_lines (job_order_id, container_number, service_request, size, fill, kind)
  select p_id, upper(trim(j->>'container_number')), j->>'service_request',
         nullif(trim(coalesce(j->>'size', '')), ''), nullif(trim(coalesce(j->>'fill', '')), ''), nullif(trim(coalesce(j->>'kind', '')), '')
  from jsonb_array_elements(p_lines) j
  where length(coalesce(trim(j->>'container_number'), '')) > 0;

  perform public.seed_job_order_billing(p_id);

  insert into public.job_order_events (job_order_id, event, actor, detail)
  values (p_id, 'edited', auth.uid(),
          jsonb_build_object('by', 'customer', 'after_filing', v_row.status = 'submitted'));
end;
$function$;
revoke all on function public.update_job_order(uuid, uuid, text, text, text, text, jsonb) from public, anon;
grant execute on function public.update_job_order(uuid, uuid, text, text, text, text, jsonb) to authenticated;

notify pgrst, 'reload schema';
