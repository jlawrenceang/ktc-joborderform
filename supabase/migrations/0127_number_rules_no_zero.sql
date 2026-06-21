-- ============================================================
-- 0127 — number rules: reject zero everywhere, amounts must be > 0, OR-number
--        validation, configurable ERP series range (owner 2026-06-21)
--
-- "No zero" pass (part 1 — validation only; no column-nullability changes here,
-- so no read-side risk). Part 2 (rate/fee placeholders → NULL) is a later
-- migration paired with the payment/rate-calc read-side handling.
-- ============================================================

-- 1) ERP control-no. normalizer now REJECTS all-zeros (release path).
create or replace function public.normalize_erp_invoice_no(p text)
returns text language plpgsql immutable as $$
declare m text[];
begin
  m := regexp_match(upper(trim(coalesce(p, ''))), '^(OR|BI)-?INV-?0*([0-9]{1,8})$');
  if m is null or m[2]::bigint = 0 then
    raise exception 'Enter a valid ERP control no. — OR-INV-… for cash, BI-INV-… for credit (non-zero).';
  end if;
  return m[1] || '-INV-' || lpad(m[2], 8, '0');
end;
$$;

-- 2) JO invoice path: same zero-reject on the ERP control no. AND the pad serial.
create or replace function public.record_service_invoice(p_id uuid, p_invoice_no text, p_pad_no text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v   text := upper(regexp_replace(coalesce(p_invoice_no, ''), '\s', '', 'g'));
  pad text := regexp_replace(coalesce(p_pad_no, ''), '\s', '', 'g');
  m   text[];
  v_status text;
begin
  if not public.has_permission('record_invoice') then
    raise exception 'You don''t have permission to record invoices.';
  end if;
  select status into v_status from public.job_orders where id = p_id;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status <> 'completed' then
    raise exception 'An invoice can only be recorded on a completed order (this one is %).', v_status
      using errcode = 'check_violation';
  end if;

  m := regexp_match(v, '^(OR|BI)-?INV-?0*(\d{1,8})$');
  if m is null or m[2]::bigint = 0 then
    raise exception 'ERP control no. not recognized — format OR-INV-00135921 (cash) or BI-INV-00220871 (credit), non-zero.'
      using errcode = 'check_violation';
  end if;
  v := m[1] || '-INV-' || lpad(m[2], 8, '0');
  if pad !~ '^\d{4,8}$' or pad::bigint = 0 then
    raise exception 'Invoice serial not recognized — enter the printed OR / Billing Invoice pad number, digits only, non-zero (e.g. 001323).'
      using errcode = 'check_violation';
  end if;

  update public.job_orders
  set service_invoice_no  = v,
      invoice_pad_no      = pad,
      invoice_recorded_at = now()
  where id = p_id;
end;
$$;

-- 3) Release Record-OR: validate the OR number (digits, non-zero) + enforce an
--    OPTIONAL ERP series range (configured later via pricing_settings keys
--    'erp_series_min' / 'erp_series_max'; unset = no range enforced yet).
create or replace function public.record_release_or(p_id uuid, p_or text, p_invoice_no text)
returns void language plpgsql security definer set search_path = public as $$
declare v_si text; v_or text; v_num bigint; v_min numeric; v_max numeric;
begin
  if not (public.has_permission('review_payments') or public.has_permission('record_invoice')) then
    raise exception 'You don''t have permission to record the OR.';
  end if;

  v_or := regexp_replace(coalesce(p_or, ''), '\s', '', 'g');
  if v_or !~ '^[0-9]{1,12}$' or v_or::bigint = 0 then
    raise exception 'Enter a valid OR number — digits only, non-zero.';
  end if;

  v_si  := public.normalize_erp_invoice_no(p_invoice_no);   -- raises if blank/zero/invalid
  v_num := regexp_replace(v_si, '\D', '', 'g')::bigint;
  select value into v_min from public.pricing_settings where key = 'erp_series_min';
  select value into v_max from public.pricing_settings where key = 'erp_series_max';
  if v_min is not null and v_num < v_min then
    raise exception 'ERP control no. % is below the accredited series (min %).', v_si, v_min::bigint;
  end if;
  if v_max is not null and v_num > v_max then
    raise exception 'ERP control no. % is above the accredited series (max %).', v_si, v_max::bigint;
  end if;

  if exists (select 1 from public.release_supplements s
             where s.release_order_id = p_id and s.payment_status <> 'confirmed') then
    raise exception 'An additional charge is still unpaid — it must be settled before the OR.';
  end if;

  update public.release_orders
     set or_number           = v_or,
         service_invoice_no  = v_si,
         invoice_recorded_at = now(),
         released_at         = now(),
         status              = 'released'
   where id = p_id and status = 'paid';
  if not found then raise exception 'The OR can only be recorded on a paid release.'; end if;
end;
$$;

-- 4) Release base charge must be > 0 (no zero-peso charge).
create or replace function public.set_release_charges(p_id uuid, p_amount numeric, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission('verify_release_docs') then raise exception 'You don''t have permission to set release charges.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Enter a charge amount greater than zero.'; end if;
  update public.release_orders
     set amount = p_amount, charges_note = nullif(trim(p_note), ''), charges_set_at = now(), status = 'payable'
   where id = p_id and status = 'docs_verified';
  if not found then raise exception 'Charges are set once, on a verified release — they can''t be revised. Add an additional charge instead.'; end if;
end;
$$;

-- 5) JO supplement amount must be > 0 (closes the zero-amount gap; default no
--    longer 0 — a missing amount now raises instead of storing an un-deletable 0).
create or replace function public.add_supplement(p_jo uuid, p_label text, p_amount numeric default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_n int; v_suffix text; v_id uuid; v_status text;
begin
  if not public.has_permission('process_job_orders') then
    raise exception 'You don''t have permission to add a charge.';
  end if;
  if length(coalesce(trim(p_label), '')) = 0 then raise exception 'Enter a charge label.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Enter a charge amount greater than zero.'; end if;
  select status into v_status from public.job_orders where id = p_jo for update;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status in ('cancelled','rejected','held') then
    raise exception 'Can''t add a charge to a % order.', v_status;
  end if;
  select count(*) into v_n from public.jo_supplements where job_order_id = p_jo;
  if v_n >= 26 then raise exception 'Too many supplements on this order.'; end if;
  v_suffix := chr(65 + v_n);
  insert into public.jo_supplements (job_order_id, suffix, label, amount, created_by)
    values (p_jo, v_suffix, trim(p_label), p_amount, auth.uid())
    returning id into v_id;

  if v_status = 'completed' then
    update public.job_orders set status = 'processing', completed_at = null where id = p_jo;
  end if;

  perform public.log_jo_event(p_jo, 'supplement_added',
    jsonb_build_object('suffix', v_suffix, 'label', trim(p_label), 'amount', p_amount));
  insert into public.notifications (customer_id, job_order_id, kind, title)
    select customer_id, p_jo, 'rps',
           'An additional charge (' || trim(p_label) || ') was added to ' ||
           coalesce(jo_number, 'your job order') || ' — please settle it to proceed.'
    from public.job_orders where id = p_jo;
  return v_id;
end;
$$;
