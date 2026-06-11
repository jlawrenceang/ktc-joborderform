-- ============================================================
-- 0044 — recording an invoice now requires BOTH control numbers
-- (decision 2026-06-12, refines G9 / 0043):
--
--   * ERP control no. — OR-INV-######## (cash) / BI-INV-######## (credit);
--     stored normalized in service_invoice_no (unchanged column).
--   * Printed invoice serial — the OR / Billing Invoice pad number
--     (4–8 digits, e.g. 094303 / 087865 / 001323); NEW column
--     invoice_pad_no, leading zeros preserved.
--
-- Both validated, both required, set atomically — the EOD audit can
-- cross-check the ERP record and the physical pad. "Invoice on file =
-- released" still keys off service_invoice_no.
-- ============================================================

alter table public.job_orders add column if not exists invoice_pad_no text;

-- The signature changes (extra arg) — drop the old one so PostgREST
-- doesn't see two overloads.
drop function if exists public.record_service_invoice(uuid, text);

create or replace function public.record_service_invoice(p_id uuid, p_invoice_no text, p_pad_no text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v   text := upper(regexp_replace(coalesce(p_invoice_no, ''), '\s', '', 'g'));
  pad text := regexp_replace(coalesce(p_pad_no, ''), '\s', '', 'g');
  m   text[];
begin
  if not public.has_permission('record_invoice') then
    raise exception 'You don''t have permission to record invoices.';
  end if;

  m := regexp_match(v, '^(OR|BI)-?INV-?0*(\d{1,8})$');
  if m is null then
    raise exception 'ERP control no. not recognized — format OR-INV-00135921 (cash) or BI-INV-00220871 (credit).'
      using errcode = 'check_violation';
  end if;
  v := m[1] || '-INV-' || lpad(m[2], 8, '0');

  if pad !~ '^\d{4,8}$' then
    raise exception 'Invoice serial not recognized — enter the printed OR / Billing Invoice pad number, digits only (e.g. 001323).'
      using errcode = 'check_violation';
  end if;

  update public.job_orders
  set service_invoice_no  = v,
      invoice_pad_no      = pad,
      invoice_recorded_at = now()
  where id = p_id;
  if not found then raise exception 'Job order not found.'; end if;
end;
$$;

revoke all on function public.record_service_invoice(uuid, text, text) from public, anon;
grant execute on function public.record_service_invoice(uuid, text, text) to authenticated;

-- Audit detail carries both numbers.
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
  if old.payment_status is distinct from new.payment_status then
    perform public.log_jo_event(new.id, 'payment_' || new.payment_status,
      jsonb_build_object('note', new.payment_note));
  end if;
  if old.service_invoice_no is distinct from new.service_invoice_no and new.service_invoice_no is not null then
    perform public.log_jo_event(new.id, 'invoice_recorded',
      jsonb_build_object('si', new.service_invoice_no, 'pad', new.invoice_pad_no));
  end if;
  if old.archived_at is null and new.archived_at is not null then
    perform public.log_jo_event(new.id, 'archived', '{}'::jsonb);
  end if;
  return new;
end;
$$;
