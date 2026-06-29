-- ============================================================
-- 0220 — DESTRUCTIVE: drop the old X-ray billing (ADR-0037 Phase A cutover · Stage 2g)
--
-- The charges spine is now the ONLY X-ray billing path (frontend + RPCs cut over).
-- This retires the old base/RPS/supplement/service-invoice billing entirely:
--   1) recreate the 7 functions that still referenced the doomed columns, charge-derived;
--   2) drop the dead RPCs + their triggers (by name, CASCADE);
--   3) drop the jo_supplements table;
--   4) drop the job_orders billing columns.
-- KEPT: rps_status / rps_path / rps_assessed_* / rps_moves (X-ray ASSESSMENT data),
-- terminal_rates (calculator), and the entire release desk (its own billing columns,
-- charge-shadowed — a fast-follow). Verify.tsx's verify_job_order keeps its exact
-- signature (payment_status / rps_payment_status now DERIVED from charges).
-- ============================================================

-- ---------- 1) recreate the column-referencing functions (charge-derived / clean) ----------

-- record_rps_assessment — drop the rps_payment_* reset (those columns are going).
create or replace function public.record_rps_assessment(p_jo uuid, p_needed boolean, p_path text, p_moves jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  if not public.has_permission('assess_rps') then
    raise exception 'You don''t have permission to assess RPS.';
  end if;
  select status into v_status from public.job_orders where id = p_jo for update;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status not in ('submitted','processing','on_hold') then
    raise exception 'This order is % — RPS can only be assessed on an open order.', v_status
      using errcode = 'check_violation';
  end if;
  update public.job_orders
     set rps_status = case when p_needed then 'needed' else 'not_needed' end,
         rps_path = p_path, rps_assessed_at = now(), rps_assessed_by = auth.uid()
   where id = p_jo;
  delete from public.rps_moves where job_order_id = p_jo;
  if p_needed and p_moves is not null then
    insert into public.rps_moves (job_order_id, move_type, qty)
    select p_jo, key, value::int from jsonb_each_text(p_moves) where coalesce(value, '0')::int > 0;
  end if;
  perform public.seed_rps_charges(p_jo);
end;
$$;
revoke all on function public.record_rps_assessment(uuid, boolean, text, jsonb) from public, anon;
grant execute on function public.record_rps_assessment(uuid, boolean, text, jsonb) to authenticated;

-- audit_job_orders — drop the payment_/invoice_recorded events (charge events live in charge_audit).
create or replace function public.audit_job_orders()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_jo_event(new.id, 'filed', jsonb_build_object('status', new.status));
    return new;
  end if;
  if old.status is distinct from new.status then
    perform public.log_jo_event(new.id, 'status_changed',
      jsonb_build_object('from', old.status, 'to', new.status, 'note', new.admin_note));
  end if;
  if old.archived_at is null and new.archived_at is not null then
    perform public.log_jo_event(new.id, 'archived', '{}'::jsonb);
  end if;
  return new;
end;
$$;

-- release_held_job_orders — exclude PAID orders via a confirmed charge (was service_invoice_no).
create or replace function public.release_held_job_orders()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status is distinct from new.status then
    if new.status = 'approved' then
      update public.job_orders set status = 'submitted'
        where customer_id = new.id and status = 'held';
    elsif new.status in ('suspended','rejected') then
      update public.job_orders
         set status = 'cancelled',
             admin_note = case when new.status = 'suspended'
               then 'Account suspended — job order cancelled.'
               else 'Account not approved — job order cancelled.' end
       where customer_id = new.id
         and status in ('held','submitted','processing','on_hold')
         and not exists (select 1 from public.charges c
                         where c.job_order_id = job_orders.id and c.payment_status = 'confirmed');
    end if;
  end if;
  return new;
end;
$$;

-- review_consignee — same charge-based paid exclusion on the reject cascade.
create or replace function public.review_consignee(p_id uuid, p_action text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_status text; v_name text;
begin
  if not (public.has_permission('review_consignee_requests') or public.is_admin()) then
    raise exception 'You don''t have permission to review consignees.';
  end if;
  v_status := case p_action
    when 'approve' then 'approved' when 'reject' then 'rejected' when 'needs_info' then 'needs_info'
    else null end;
  if v_status is null then raise exception 'Unknown action: %', p_action; end if;
  if p_action in ('reject', 'needs_info') and coalesce(trim(p_note), '') = '' then
    raise exception 'Add a note for the customer explaining what''s needed.';
  end if;
  update public.consignees
     set status = v_status, decided_at = now(),
         note = case when p_action = 'approve' then null else trim(p_note) end
   where id = p_id returning name into v_name;
  if not found then raise exception 'Consignee not found.'; end if;
  if p_action = 'reject' then
    update public.job_orders
       set status = 'cancelled',
           admin_note = 'Consignee "' || coalesce(v_name, '') || '" was not approved: ' || trim(p_note)
     where consignee_id = p_id
       and status in ('held','submitted','processing','on_hold')
       and not exists (select 1 from public.charges c
                       where c.job_order_id = job_orders.id and c.payment_status = 'confirmed');
  end if;
end;
$$;

-- archive_done_orders — completion now guarantees charges paid, so archive any completed order.
create or replace function public.archive_done_orders()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  if auth.uid() is not null and not public.has_permission('process_job_orders') then
    raise exception 'You don''t have permission to archive job orders.';
  end if;
  update public.job_orders set archived_at = now()
  where status = 'completed' and archived_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- resubmit_needs_info — a container change re-seeds the base charge (was: reset invoice columns).
create or replace function public.resubmit_needs_info(
  p_id uuid, p_note text, p_consignee_id uuid default null, p_entry_number text default null,
  p_vessel_visit text default null, p_vessel_name text default null, p_voyage_number text default null,
  p_lines jsonb default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_row public.job_orders%rowtype; v_fields text[]; v_count int := 0; e jsonb;
begin
  if length(coalesce(trim(p_note), '')) = 0 then
    raise exception 'Please describe what you updated or clarified.' using errcode = 'check_violation';
  end if;
  select * into v_row from public.job_orders
    where id = p_id and customer_id = public.current_broker_id() for update;
  if not found then raise exception 'Job order not found.'; end if;
  if v_row.status <> 'on_hold' then raise exception 'Only orders on hold can be resubmitted this way.'; end if;
  v_fields := coalesce(v_row.needs_fields, '{}');

  if 'consignee' = any(v_fields) then
    if p_consignee_id is null then raise exception 'Select a consignee.' using errcode = 'check_violation'; end if;
    if not exists (select 1 from public.consignees where id = p_consignee_id) then raise exception 'Consignee not found.'; end if;
    update public.job_orders set consignee_id = p_consignee_id where id = p_id;
  end if;
  if 'entry' = any(v_fields) then
    if length(coalesce(trim(p_entry_number), '')) = 0 then raise exception 'Enter the Entry Number (C-…).' using errcode = 'check_violation'; end if;
    update public.job_orders set entry_number = upper(trim(p_entry_number)) where id = p_id;
  end if;
  if 'vessel' = any(v_fields) then
    if coalesce(nullif(trim(p_vessel_name), ''), '') = '' or coalesce(nullif(trim(p_voyage_number), ''), '') = '' then
      raise exception 'Enter the vessel name and voyage number.' using errcode = 'check_violation';
    end if;
    update public.job_orders set vessel_visit = nullif(trim(p_vessel_visit), ''),
      vessel_name = upper(trim(p_vessel_name)), voyage_number = upper(trim(p_voyage_number)) where id = p_id;
  end if;
  if 'containers' = any(v_fields) then
    for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
      if length(coalesce(trim(e->>'container_number'), '')) > 0 then v_count := v_count + 1; end if;
    end loop;
    if v_count = 0 then raise exception 'Add at least one container.' using errcode = 'check_violation'; end if;
    delete from public.job_order_lines where job_order_id = p_id;
    insert into public.job_order_lines (job_order_id, container_number, service_request)
      select p_id, upper(trim(j->>'container_number')), j->>'service_request'
      from jsonb_array_elements(p_lines) j
      where length(coalesce(trim(j->>'container_number'), '')) > 0;
    -- 0220: the new container set invalidates the old base charge — rebuild it from the
    -- new lines (seed_job_order_billing re-links containers + re-seeds the base charge,
    -- money-safe), and clear every service/X-ray completion (new boxes weren't inspected).
    perform public.seed_job_order_billing(p_id);
    delete from public.service_completions where job_order_id = p_id;
    update public.job_order_lines set xray_done_at = null, xray_done_by = null, xray_done_by_name = null
     where job_order_id = p_id;
  end if;

  update public.job_orders
     set status = 'submitted', customer_note = trim(p_note),
         needs_fields = null, last_customer_edit_at = now()
   where id = p_id;
end;
$$;

-- verify_job_order — SAME signature (Verify.tsx untouched); payment fields DERIVED from charges.
create or replace function public.verify_job_order(p_id uuid)
returns table(jo_number text, status text, payment_status text, rps_status text,
              rps_payment_status text, completed_at timestamptz, consignee text, containers text[])
language sql security definer set search_path = public as $$
  select jo.jo_number, jo.status,
    case when exists (select 1 from public.charges c where c.job_order_id = jo.id and c.charge_type = 'service'
                        and c.bill_status = 'billed' and c.payment_status not in ('confirmed','reversed'))
         then 'unpaid' else 'confirmed' end,
    jo.rps_status,
    case when exists (select 1 from public.charges c where c.job_order_id = jo.id and c.charge_type = 'rps'
                        and c.bill_status = 'billed' and c.payment_status not in ('confirmed','reversed'))
         then 'unpaid' else 'confirmed' end,
    jo.completed_at,
    (select c.code || ' – ' || c.name from public.consignees c where c.id = jo.consignee_id),
    (select array_agg(l.container_number order by l.container_number)
       from public.job_order_lines l where l.job_order_id = jo.id)
  from public.job_orders jo
  where jo.id = p_id;
$$;

-- ---------- 2) drop the dead RPCs + their triggers (by name, all overloads, CASCADE) ----------
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure::text as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = any(array[
       'add_supplement','bill_supplement','request_supplement','submit_supplement_proof',
       'review_supplement_payment','record_supplement_office_payment','sync_open_supplement',
       'review_payment','submit_payment_proof','record_office_payment','record_service_invoice',
       'complete_on_payment_confirmed','notify_staff_payment','enforce_invoice_before_confirm'])
  loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
end $$;

-- ---------- 3) drop the supplement table (CASCADE its policies/triggers) ----------
drop table if exists public.jo_supplements cascade;

-- ---------- 4) drop the job_orders billing columns ----------
alter table public.job_orders
  drop column if exists payment_status,
  drop column if exists payment_proof_path,
  drop column if exists payment_submitted_at,
  drop column if exists payment_confirmed_at,
  drop column if exists payment_note,
  drop column if exists rps_payment_status,
  drop column if exists rps_payment_proof_path,
  drop column if exists rps_payment_submitted_at,
  drop column if exists rps_payment_confirmed_at,
  drop column if exists rps_payment_note,
  drop column if exists service_invoice_no,
  drop column if exists invoice_pad_no,
  drop column if exists has_open_supplement;

notify pgrst, 'reload schema';
