-- ============================================================
-- 0199 — submit_supplement_proof: terminal / payment-state / bill guards (audit #6)
--
-- The JO-side twin of 0194 (release supplements). submit_supplement_proof (0101)
-- set payment_status = 'submitted' for ANY supplement the customer owns — no check
-- that the charge is actually awaiting payment, that it's been billed, or that the
-- parent JO is still live. So a customer could (re)submit a proof on an already-
-- confirmed charge, an unbilled charge, or a charge on a cancelled/rejected/
-- completed JO — stranded money with no clean review path.
--
-- Fix: scope the update to payment_status in ('unpaid','rejected') AND
-- bill_status = 'billed' AND the parent JO not terminal. Recreated verbatim from
-- 0101 with ONLY those conditions added (mirrors submit_release_supplement_payment).
-- ============================================================

create or replace function public.submit_supplement_proof(p_supp uuid, p_path text)
returns void language plpgsql security definer set search_path = public as $$
declare v_jo uuid;
begin
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then
    raise exception 'Invalid proof path.';
  end if;
  select s.job_order_id into v_jo from public.jo_supplements s
    join public.job_orders jo on jo.id = s.job_order_id
    where s.id = p_supp
      and jo.customer_id = public.current_broker_id()
      and s.payment_status in ('unpaid', 'rejected')
      and s.bill_status = 'billed'
      and jo.status not in ('cancelled', 'rejected', 'completed')
      for update;
  if not found then raise exception 'This charge is not awaiting payment.'; end if;
  update public.jo_supplements
    set payment_status = 'submitted', payment_proof_path = p_path,
        payment_submitted_at = now(), payment_note = null
    where id = p_supp;
  insert into public.staff_notifications (required_permission, kind, title, job_order_id)
    values ('review_payments', 'payment', 'Additional-charge payment proof uploaded', v_jo);
end;
$$;
revoke all on function public.submit_supplement_proof(uuid, text) from public, anon;
grant execute on function public.submit_supplement_proof(uuid, text) to authenticated;
