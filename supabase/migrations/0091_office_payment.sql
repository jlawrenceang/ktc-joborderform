-- ============================================================
-- 0091 — record a walk-in / office payment (owner, 2026-06-16)
--
-- review_payment confirms an UPLOADED online proof. Customers can also pay at
-- the cashier window (we still nudge them online to skip the line), so the
-- cashier needs to mark an order paid without a proof on file. This sets
-- payment_status = 'confirmed' directly (gated to review_payments) and logs an
-- office-payment event. Confirming payment trips the two-gate auto-complete
-- (complete_on_payment_confirmed) when every service is already done.
-- ============================================================

create or replace function public.record_office_payment(p_id uuid, p_kind text default 'base', p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  if not public.has_permission('review_payments') then
    raise exception 'You don''t have permission to record payments.';
  end if;
  if p_kind not in ('base','rps') then
    raise exception 'Unknown payment kind %.', p_kind;
  end if;

  if p_kind = 'rps' then
    select rps_payment_status into v_status from public.job_orders where id = p_id for update;
  else
    select payment_status into v_status from public.job_orders where id = p_id for update;
  end if;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status = 'confirmed' then raise exception 'This payment is already confirmed.'; end if;

  if p_kind = 'rps' then
    update public.job_orders
       set rps_payment_status = 'confirmed', rps_payment_confirmed_at = now(), rps_payment_note = null
     where id = p_id;
  else
    update public.job_orders
       set payment_status = 'confirmed', payment_confirmed_at = now(), payment_note = null
     where id = p_id;
  end if;

  perform public.log_jo_event(p_id, 'payment_office', jsonb_build_object('kind', p_kind, 'note', nullif(trim(coalesce(p_note, '')), '')));
end;
$$;
revoke all on function public.record_office_payment(uuid, text, text) from public, anon;
grant execute on function public.record_office_payment(uuid, text, text) to authenticated;
