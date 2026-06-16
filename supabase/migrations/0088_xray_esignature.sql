-- ============================================================
-- 0088 — X-ray e-signature: snapshot the confirming Checker's name (owner, 2026-06-16)
--
-- record_van_xray already stamps WHO confirmed (xray_done_by = auth.uid()) and
-- WHEN. For an e-signature on the document we also snapshot the checker's NAME
-- at sign time (immutable — the signature stays correct even if the staff
-- account is later renamed/removed), so the slip can show "X-rayed by <name>".
-- ============================================================

alter table public.job_order_lines add column if not exists xray_done_by_name text;

create or replace function public.record_van_xray(p_line_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_jo        uuid;
  v_svc       text;
  v_status    text;
  v_remaining int;
  v_signer    text := (select full_name from public.customers where user_id = auth.uid());
begin
  if not public.has_permission('confirm_xray') then
    raise exception 'You don''t have permission to confirm X-ray.';
  end if;
  select l.job_order_id, l.service_request into v_jo, v_svc
    from public.job_order_lines l where l.id = p_line_id;
  if v_jo is null then raise exception 'Container line not found.'; end if;
  if public.service_line_of(v_svc) <> 'xray' then
    raise exception 'This container does not need X-ray.';
  end if;
  select status into v_status from public.job_orders where id = v_jo for update;
  if v_status not in ('submitted','processing','on_hold') then
    raise exception 'This order is % — only open orders can be confirmed.', v_status;
  end if;

  update public.job_order_lines
    set xray_done_at      = coalesce(xray_done_at, now()),
        xray_done_by      = coalesce(xray_done_by, auth.uid()),
        xray_done_by_name = coalesce(xray_done_by_name, v_signer)
    where id = p_line_id;

  select count(*) into v_remaining
    from public.job_order_lines l
    where l.job_order_id = v_jo
      and public.service_line_of(l.service_request) = 'xray'
      and l.xray_done_at is null;

  if v_remaining = 0 then
    perform public.record_service_done(v_jo, 'xray', now());
  elsif v_status = 'submitted' then
    update public.job_orders set status = 'processing' where id = v_jo;
  end if;
end;
$$;
revoke all on function public.record_van_xray(uuid) from public, anon;
grant execute on function public.record_van_xray(uuid) to authenticated;
