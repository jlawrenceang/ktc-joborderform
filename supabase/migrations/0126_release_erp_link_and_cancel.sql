-- ============================================================
-- 0126 — release ERP link (combined Record-OR + ERP control no.) + cancel
--        (owner 2026-06-21, extends ADR-0024)
--
-- The app does NOT generate official invoices — KTC's Frappe ERP does. Recording
-- the ERP service-invoice control number against a release is the LINK between the
-- app's release record and the ERP document. Per owner: the cashier records the
-- physical OR number AND the ERP control no. in ONE action (the box can't be
-- released without the ERP number on hand).
--
-- Also: a release can now be CANCELLED (customer or staff) before it's paid —
-- making the previously-dead 'cancelled' status live.
-- ============================================================

-- 1) ERP-link columns (or_number stays = the physical OR/pad serial the customer holds).
alter table public.release_orders
  add column if not exists service_invoice_no  text,
  add column if not exists invoice_recorded_at timestamptz;

-- 2) Shared ERP control-no. validator/normalizer (mirrors the JO record_service_invoice
--    rule). 'or-inv-1323' -> 'OR-INV-00001323'. Raises on a malformed value.
create or replace function public.normalize_erp_invoice_no(p text)
returns text language plpgsql immutable as $$
declare m text[];
begin
  m := regexp_match(upper(trim(coalesce(p, ''))), '^(OR|BI)-?INV-?0*([0-9]{1,8})$');
  if m is null then
    raise exception 'Enter a valid ERP control no. — OR-INV-… for cash, BI-INV-… for credit.';
  end if;
  return m[1] || '-INV-' || lpad(m[2], 8, '0');
end;
$$;
revoke all on function public.normalize_erp_invoice_no(text) from public, anon;
grant execute on function public.normalize_erp_invoice_no(text) to authenticated;

-- 3) Record OR + ERP control no. in one step; releases the container.
--    (0125 owns the 2-arg version — drop it before redefining with the new signature.)
drop function if exists public.record_release_or(uuid, text);
create or replace function public.record_release_or(p_id uuid, p_or text, p_invoice_no text)
returns void language plpgsql security definer set search_path = public as $$
declare v_si text;
begin
  if not (public.has_permission('review_payments') or public.has_permission('record_invoice')) then
    raise exception 'You don''t have permission to record the OR.';
  end if;
  if coalesce(trim(p_or), '') = '' then raise exception 'Enter the OR number.'; end if;
  v_si := public.normalize_erp_invoice_no(p_invoice_no);   -- raises if blank/invalid
  if exists (select 1 from public.release_supplements s
             where s.release_order_id = p_id and s.payment_status <> 'confirmed') then
    raise exception 'An additional charge is still unpaid — it must be settled before the OR.';
  end if;
  update public.release_orders
     set or_number           = upper(trim(p_or)),
         service_invoice_no  = v_si,
         invoice_recorded_at = now(),
         released_at         = now(),
         status              = 'released'
   where id = p_id and status = 'paid';
  if not found then raise exception 'The OR can only be recorded on a paid release.'; end if;
end;
$$;
revoke all on function public.record_release_or(uuid, text, text) from public, anon;
grant execute on function public.record_release_or(uuid, text, text) to authenticated;

-- 4) Cancel a release — the owning customer OR a staff member, only before payment.
create or replace function public.cancel_release_order(p_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_status text; v_staff boolean;
begin
  select customer_id, status into v_owner, v_status from public.release_orders where id = p_id;
  if not found then raise exception 'Release not found.'; end if;
  v_staff := public.has_permission('verify_release_docs') or public.has_permission('review_payments');
  if not (v_owner = public.current_broker_id() or v_staff) then
    raise exception 'You can''t cancel this release.';
  end if;
  if v_status not in ('submitted', 'docs_verified', 'payable', 'on_hold') then
    raise exception 'This release can no longer be cancelled — it''s already paid or released.';
  end if;
  update public.release_orders
     set status     = 'cancelled',
         staff_note = case when v_staff and coalesce(trim(p_reason), '') <> ''
                          then trim(p_reason) else staff_note end
   where id = p_id;
end;
$$;
revoke all on function public.cancel_release_order(uuid, text) from public, anon;
grant execute on function public.cancel_release_order(uuid, text) to authenticated;
