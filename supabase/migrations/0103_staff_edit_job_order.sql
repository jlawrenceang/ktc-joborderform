-- ============================================================
-- 0103 — staff edit JO header data (owner, 2026-06-16)
--
-- Owner spec (#4): "we should be able to fix the JO data so it's editable by
-- staff — mainly cashier, operations and customer service. Operations can edit
-- necessary data like vessel/voyage." Customers can already self-edit their own
-- order while held/submitted (update_job_order); this is the STAFF path for the
-- operational header fields (consignee, entry, vessel/voyage), gated to the
-- back-office roles that actually correct data — NOT the checker (who only
-- confirms X-ray) and NOT customers.
--
-- Scope is deliberately the header only — container lines, status, payment and
-- queue numbers are all managed by their own guarded flows and are left alone.
-- ============================================================

create or replace function public.staff_edit_job_order(
  p_id          uuid,
  p_consignee   uuid    default null,
  p_entry       text    default null,
  p_vessel_name text    default null,
  p_voyage      text    default null,
  p_vessel_visit text   default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  -- Cashier (review_payments), operations (process_job_orders) or CSR
  -- (manage_support). The checker has neither — it can't edit JO data.
  if not (public.has_permission('process_job_orders')
          or public.has_permission('review_payments')
          or public.has_permission('manage_support')) then
    raise exception 'You don''t have permission to edit this order.';
  end if;

  select status into v_status from public.job_orders where id = p_id for update;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status in ('cancelled', 'rejected') then
    raise exception 'Can''t edit a % order.', v_status;
  end if;

  -- A consignee, when supplied, must exist; null keeps the current one.
  if p_consignee is not null and not exists (select 1 from public.consignees where id = p_consignee) then
    raise exception 'Consignee not found.';
  end if;

  update public.job_orders set
    consignee_id  = coalesce(p_consignee, consignee_id),
    entry_number  = nullif(trim(coalesce(p_entry, '')), ''),
    vessel_name   = nullif(trim(coalesce(p_vessel_name, '')), ''),
    voyage_number = nullif(trim(coalesce(p_voyage, '')), ''),
    vessel_visit  = nullif(trim(coalesce(p_vessel_visit, '')), '')
  where id = p_id;

  perform public.log_jo_event(p_id, 'staff_edited',
    jsonb_build_object('entry', p_entry, 'vessel', p_vessel_name, 'voyage', p_voyage));
end;
$$;
revoke all on function public.staff_edit_job_order(uuid, uuid, text, text, text, text) from public, anon;
grant execute on function public.staff_edit_job_order(uuid, uuid, text, text, text, text) to authenticated;
