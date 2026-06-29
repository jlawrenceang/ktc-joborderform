-- ============================================================
-- 0224 — Low-edge hardening from the pre-go-live battery
--
-- L1: a charge with an UNCONFIGURED rate (amount NULL, or 0) could be invoiced,
--     confirmed, and complete the order at zero recorded revenue — record_charge_invoice
--     gated only on invoice_state/erp/bir, never on amount. Block it at the earliest
--     money gate: you cannot record a FINAL invoice on a charge with no configured
--     amount (forces the admin to set the service rate first). Since confirm +
--     payment-order collection both require a final invoice, this closes the whole path.
-- L2: effective_rate(uuid,text) was EXECUTE-able by `authenticated` (0206 revoked only
--     public/anon), so any logged-in customer could RPC it with a consignee uuid and read
--     that consignee's confidential per-consignee override rate. Revoke from authenticated;
--     the definer functions that use it (add_charge, seed_job_order_billing, seed_rps_charges)
--     run as the owner and are unaffected.
-- ============================================================

-- L1 — require a configured, positive amount before a charge can be invoiced.
create or replace function public.record_charge_invoice(p_charge uuid, p_erp text, p_bir text)
returns void language plpgsql security definer set search_path = public as $$
declare v_erp text := upper(regexp_replace(coalesce(p_erp,''), '\s', '', 'g'));
        v_bir text := regexp_replace(coalesce(p_bir,''), '\s', '', 'g'); m text[]; v_amount numeric;
begin
  if not public.has_permission('record_invoice') then raise exception 'You don''t have permission to record invoices.'; end if;
  select amount into v_amount from public.charges where id = p_charge;
  if v_amount is null or v_amount <= 0 then
    raise exception 'Set the charge rate first — this charge has no configured amount to invoice.' using errcode='check_violation';
  end if;
  m := regexp_match(v_erp, '^(OR|BI)-?INV-?0*(\d{1,8})$');
  if m is null or m[2]::bigint = 0 then
    raise exception 'ERP control no. not recognized — format OR-INV-00135921 (cash) or BI-INV-00220871 (credit), non-zero.' using errcode='check_violation';
  end if;
  v_erp := m[1] || '-INV-' || lpad(m[2], 8, '0');
  if v_bir !~ '^\d{4,8}$' or v_bir::bigint = 0 then
    raise exception 'BIR invoice serial not recognized — printed pad number, 4–8 digits, non-zero.' using errcode='check_violation';
  end if;
  update public.charges
     set erp_invoice_no = v_erp, bir_invoice_no = v_bir, invoice_state = 'final', invoice_recorded_at = now()
   where id = p_charge and bill_status = 'billed' and payment_status <> 'confirmed';
  if not found then raise exception 'Invoice can only be recorded on a billed, unconfirmed charge.'; end if;
  perform public.log_charge_audit(p_charge, 'invoice_recorded', jsonb_build_object('erp',v_erp,'bir',v_bir));
end;
$$;

-- L2 — effective_rate is an internal pricing helper; a customer must not read override rates.
revoke all on function public.effective_rate(uuid, text) from authenticated;

notify pgrst, 'reload schema';
