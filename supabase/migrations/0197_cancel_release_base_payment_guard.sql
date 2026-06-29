-- ============================================================
-- 0197 — cancel_release_order: don't strand an in-flight BASE payment (audit #3)
--
-- BUG (sibling to 0131/0194): cancel_release_order blocks a cancel when a
-- SUPPLEMENT payment is submitted/confirmed, but never checks the release's own
-- BASE payment. A `payable` release whose customer has submitted the base payment
-- proof (release_orders.payment_status = 'submitted') is still inside the cancel
-- window, so a cancel strands that under-review payment — money submitted with no
-- order and no in-app refund trail, exactly the gap 0194 closed on the supplement
-- side. (A 'confirmed' base payment already moves the release to 'paid', out of the
-- cancel window, so only the 'submitted' state needs the new guard.)
--
-- Fix: refuse the cancel when the base payment is under review. Recreated verbatim
-- from 0131 with ONLY the base-payment select + guard added.
-- ============================================================

create or replace function public.cancel_release_order(p_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_status text; v_pay text; v_staff boolean;
begin
  select customer_id, status, payment_status into v_owner, v_status, v_pay
    from public.release_orders where id = p_id;
  if not found then raise exception 'Release not found.'; end if;
  v_staff := public.has_permission('verify_release_docs') or public.has_permission('review_payments');
  if not (v_owner = public.current_broker_id() or v_staff) then
    raise exception 'You can''t cancel this release.';
  end if;
  if v_status not in ('submitted', 'docs_verified', 'payable', 'on_hold') then
    raise exception 'This release can no longer be cancelled — it''s already paid or released.';
  end if;
  if v_pay = 'submitted' then
    raise exception 'This release has a base payment under review — confirm or reject it before cancelling.';
  end if;
  if exists (select 1 from public.release_supplements s
             where s.release_order_id = p_id and s.payment_status in ('submitted', 'confirmed')) then
    raise exception 'This release has a paid or pending additional charge — settle or refund it before cancelling.';
  end if;
  update public.release_orders
     set status     = 'cancelled',
         staff_note = case when v_staff and coalesce(trim(p_reason), '') <> ''
                          then trim(p_reason) else staff_note end
   where id = p_id;
end;
$$;
