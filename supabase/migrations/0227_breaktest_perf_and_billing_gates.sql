-- ============================================================
-- 0227 — Full-sandbox break-test remediation: charges read-path scaling + JO-wedge gates
--
-- HIGH (perf): the charges SELECT policies call SECURITY DEFINER functions (current_broker_id,
--   is_admin, has_permission x4) that Postgres re-evaluates PER ROW over the scanned charge set
--   — a ~50x CPU tax (desk query 247ms vs 4.6ms), flat ~7 reads/s, scaling linearly with charge
--   count. Per Supabase's RLS guidance, wrap each row-independent predicate in a scalar subselect
--   `(select fn())` so it is hoisted to a once-per-query InitPlan. Pair with a narrow open-charges
--   index (the desk query) + a job_order_lines(job_order_id) index (the reconciliation N+1).
--
-- MEDIUM (billing wedge / double-pay):
--   • add_charge accepted a negative/zero addon rate AND a NULL-amount service/rps charge (no
--     matching rate) — both insert a billed/proposed charge that record_charge_invoice can never
--     invoice (amount<=0 / NULL), so it can never confirm/reverse and the host JO is permanently
--     un-completable (no reprice RPC exists). Reject a non-positive / unrated amount at add time.
--   • submit_charge_payment let a customer pay a charge already bundled into a payment order
--     (no payment_order_id IS NULL guard) — contradicts the bundled-PO state. Mirror
--     create_payment_order's guard.
-- ============================================================

-- ---- HIGH: cache the RLS predicates (once-per-query InitPlan) ----
alter policy "customer reads own charges" on public.charges
  using (exists (select 1 from public.job_orders j
                 where j.id = charges.job_order_id and j.customer_id = (select public.current_broker_id())));

alter policy "customer reads own release charges" on public.charges
  using ((release_order_id is not null) and exists (select 1 from public.release_orders r
          where r.id = charges.release_order_id and r.customer_id = (select public.current_broker_id())));

alter policy "staff reads charges" on public.charges
  using ((select public.is_admin()
               or public.has_permission('review_payments')
               or public.has_permission('accept_orders')
               or public.has_permission('complete_orders')
               or public.has_permission('hold_reject_orders')));

-- ---- indexes (now load-bearing once the per-row RLS tax is gone) ----
-- Open-charges desk queue: bill_status='billed' AND payment_order_id IS NULL AND payment_status NOT IN (confirmed,reversed)
create index if not exists charges_open_desk_idx on public.charges (created_at)
  where bill_status = 'billed' and payment_order_id is null and payment_status not in ('confirmed','reversed');
-- Reconciliation N+1: the containers subquery seq-scans job_order_lines once per JO.
create index if not exists job_order_lines_jo_idx on public.job_order_lines (job_order_id);

-- ---- MEDIUM: add_charge — never create an un-invoiceable (non-positive / unrated) charge ----
create or replace function public.add_charge(p_jo uuid, p_type text, p_label text, p_qty numeric default 1, p_unit_rate numeric default null, p_vatable boolean default true)
returns uuid language plpgsql security definer set search_path to 'public' as $function$
declare v_id uuid; v_consignee uuid; v_status text; v_rate numeric; v_amount numeric; v_bill text;
begin
  if not (public.is_admin() or public.has_permission('accept_orders') or public.has_permission('complete_orders')) then
    raise exception 'You don''t have permission to add charges.';
  end if;
  if p_type not in ('service','rps','addon') then raise exception 'Unknown charge type.'; end if;
  if length(coalesce(trim(p_label), '')) = 0 then raise exception 'A charge label is required.' using errcode='check_violation'; end if;
  if length(p_label) > 120 then raise exception 'Charge label is too long.' using errcode='check_violation'; end if;
  if coalesce(p_qty,0) <= 0 or p_qty > 100000 then raise exception 'Enter a valid quantity.' using errcode='check_violation'; end if;
  -- a manual addon price must be positive (mirrors set_release_charges)
  if p_type = 'addon' and p_unit_rate is not null and p_unit_rate <= 0 then
    raise exception 'A charge amount must be greater than zero.' using errcode='check_violation';
  end if;
  select consignee_id, status into v_consignee, v_status from public.job_orders where id = p_jo;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status in ('cancelled','rejected') then
    raise exception 'Can''t add a charge to a % job order.', v_status using errcode='check_violation';
  end if;
  -- F1: only an add-on may carry an ad-hoc price; service/rps ALWAYS price off the spine.
  v_rate := case when p_type = 'addon' then coalesce(p_unit_rate, public.effective_rate(v_consignee, p_label))
                 else public.effective_rate(v_consignee, p_label) end;
  v_amount := case when v_rate is null then null else round(v_rate * p_qty, 2) end;
  -- never create a charge that can never be invoiced (record_charge_invoice rejects amount<=0/NULL),
  -- which would permanently wedge JO completion with no self-service reprice path.
  if v_amount is null or v_amount <= 0 then
    raise exception 'No rate is configured for "%" — set the rate before adding this charge.', trim(p_label) using errcode='check_violation';
  end if;
  v_bill := case when p_type = 'addon' then 'proposed' else 'billed' end;
  insert into public.charges (job_order_id, charge_type, label, qty, unit_rate, amount, vatable, bill_status, created_by)
  values (p_jo, p_type, trim(p_label), p_qty, v_rate, v_amount, coalesce(p_vatable,true), v_bill, auth.uid())
  returning id into v_id;
  perform public.log_charge_audit(v_id, 'created', jsonb_build_object('type',p_type,'label',trim(p_label),'qty',p_qty,'amount',v_amount,'bill_status',v_bill));
  return v_id;
end;
$function$;

-- ---- MEDIUM: submit_charge_payment — a bundled charge is paid via its payment order, not per-charge ----
create or replace function public.submit_charge_payment(p_charge uuid, p_proof text)
returns void language plpgsql security definer set search_path to 'public' as $function$
declare v_cust uuid := public.current_broker_id();
begin
  update public.charges c
     set payment_status = 'submitted', payment_proof_path = nullif(p_proof,''), payment_submitted_at = now(), payment_note = null
   where c.id = p_charge and c.bill_status = 'billed' and c.payment_status in ('unpaid','rejected')
     and c.payment_order_id is null
     and exists (select 1 from public.job_orders j where j.id = c.job_order_id and j.customer_id = v_cust);
  if not found then raise exception 'This charge is not awaiting your payment.'; end if;
  perform public.log_charge_audit(p_charge, 'payment_submitted', null);
end;
$function$;

notify pgrst, 'reload schema';
