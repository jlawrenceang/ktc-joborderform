-- 0229 — close two create_payment_order gaps found in go-live review (codex)
--
-- P1 (money-integrity blocker): a 'submitted' charge — one where the customer has
--    uploaded payment proof and is awaiting the cashier's confirm/reject — could still
--    be bundled into a walk-in Payment Order and settled by OR. That re-opens a
--    double-settlement / ambiguous-payment state, the REVERSE direction of the 0227
--    "submit_charge_payment rejects an already-bundled charge" fix. Only an unpaid or
--    rejected charge may be bundled.
-- P2: create_payment_order verified one CUSTOMER across the bundled charges but inserted
--    the caller-supplied p_consignee without checking it matches. The UI groups by
--    customer + consignee; the backend must enforce the consignee too.
--
-- Verbatim re-create of the current 0225 body (same customer pick via
-- (array_agg(distinct cust))[1], same insert/grant), with only the two guards added.

create or replace function public.create_payment_order(p_consignee uuid, p_charge_ids uuid[])
returns uuid language plpgsql security definer set search_path = public as $$
declare v_po uuid; v_cust uuid; n int;
begin
  if not public.has_permission('review_payments') then raise exception 'You don''t have permission to create a payment order.'; end if;
  if p_charge_ids is null or array_length(p_charge_ids,1) is null then raise exception 'Select at least one charge.'; end if;
  select count(distinct s.cust), (array_agg(distinct s.cust))[1] into n, v_cust
    from (
      select coalesce(j.customer_id, r.customer_id) as cust
        from public.charges c
        left join public.job_orders j     on j.id = c.job_order_id
        left join public.release_orders r on r.id = c.release_order_id
       where c.id = any(p_charge_ids)
    ) s;
  if n <> 1 then raise exception 'All charges in a payment order must belong to the same customer.' using errcode='check_violation'; end if;
  -- 0229 (P2): every bundled charge's parent consignee must equal the consignee named for
  -- the PO. `is distinct from` makes the no-consignee (NULL) group compare correctly: a PO
  -- for p_consignee=NULL accepts only charges whose parent consignee is also NULL.
  if exists (
    select 1 from public.charges c
      left join public.job_orders j     on j.id = c.job_order_id
      left join public.release_orders r on r.id = c.release_order_id
     where c.id = any(p_charge_ids)
       and coalesce(j.consignee_id, r.consignee_id) is distinct from p_consignee
  ) then
    raise exception 'All charges in a payment order must belong to the consignee named for it.' using errcode='check_violation';
  end if;
  -- 0229 (P1): only an unpaid/rejected charge may be bundled. A 'submitted' charge is awaiting
  -- the cashier's confirm/reject of the customer's proof; bundling it would let the same charge
  -- be settled twice (reverse of the 0227 submit-on-bundled block). Excludes confirmed/reversed too.
  if exists (select 1 from public.charges c where c.id = any(p_charge_ids)
             and (c.bill_status <> 'billed' or c.payment_status not in ('unpaid','rejected') or c.payment_order_id is not null)) then
    raise exception 'One or more charges can''t be bundled (already paid/submitted/reversed, unbilled, or in another payment order).' using errcode='check_violation';
  end if;
  insert into public.payment_orders (po_number, customer_id, consignee_id, created_by)
  values ('PO-' || lpad(nextval('payment_order_seq')::text, 6, '0'), v_cust, p_consignee, auth.uid())
  returning id into v_po;
  update public.charges set payment_order_id = v_po where id = any(p_charge_ids);
  return v_po;
end;
$$;
revoke all on function public.create_payment_order(uuid, uuid[]) from public, anon;
grant execute on function public.create_payment_order(uuid, uuid[]) to authenticated;

notify pgrst, 'reload schema';
