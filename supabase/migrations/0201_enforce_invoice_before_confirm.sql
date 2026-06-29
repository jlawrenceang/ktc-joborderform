-- ============================================================
-- 0201 — Invoice-before-confirm gate, enforced at the DB (audit #4)
--
-- The BIR invoice-before-confirm rule lived only in the record_service_invoice /
-- review_payment RPCs. The broad "admin updates job orders" UPDATE policy (0029)
-- let a raw UPDATE set payment_status='confirmed' (or rps_payment_status) without
-- a service_invoice_no — bypassing the gate (and then complete_on_payment_confirmed
-- auto-completes the order). This moves the gate to a BEFORE UPDATE trigger so the
-- raw path can't skip it.
--
-- Scope: the BASE payment only. RPS is a SEPARATE payable with no invoice
-- requirement — review_payment / record_office_payment (0186) gate the invoice
-- check on `p_kind <> 'rps'`, and there is no rps invoice field (0063: "pay the
-- X-ray now, the RPS later — or both at once"). So the trigger must NOT fire on
-- rps_payment_status, or it would block every legitimate RPS confirm.
--
-- Legit base flow is unchanged: record_service_invoice sets service_invoice_no
-- FIRST, then the confirm sees it set and passes. Only a BASE confirm with NO
-- invoice is blocked. (Trigger is BEFORE UPDATE only — inserts/backfills unaffected.)
-- ============================================================

create or replace function public.enforce_invoice_before_confirm()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.payment_status = 'confirmed' and old.payment_status is distinct from 'confirmed' then
    if coalesce(nullif(trim(new.service_invoice_no), ''), null) is null then
      raise exception 'Record the service invoice number before confirming payment.'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_invoice_before_confirm() from public, anon, authenticated;

-- Runs before complete_on_payment_confirmed (alphabetical 'a' < 'c' on trigger name
-- ensures the gate fires first), so a no-invoice confirm is blocked before any
-- auto-complete can act.
drop trigger if exists a_enforce_invoice_before_confirm on public.job_orders;
create trigger a_enforce_invoice_before_confirm
  before update on public.job_orders
  for each row execute function public.enforce_invoice_before_confirm();
