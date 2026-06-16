-- ============================================================
-- 0094 — security hardening from the 3-way review (owner, 2026-06-16)
--
-- Codex + two review agents converged. No critical holes (customers can't
-- self-escalate, non-root can't mint owners, supported completion paths enforce
-- the two gates). These close the defense-in-depth gaps on trusted/admin paths:
--   1. Completion is enforced at the DB for EVERY path (the broad admin UPDATE
--      policy could raw-set status='completed' without the two gates).
--   2. Changing is_admin is owner-only (staff are owner-invite-only) — a plain
--      admin could laterally mint another admin via a raw row update.
--   3. record_service_invoice (= "PAID/released") requires a completed order.
--   4. submit_payment_proof refuses a `held` (unverified-customer draft) order.
--   5. Exactly one root owner (DB-enforced).
--   6. Security alerts go to the ROOT owner, deterministically.
-- ============================================================

-- ---------- 1) DB-level two-gate completion (catches the raw admin UPDATE) ----------
-- Uses NEW values so it agrees with the auto-complete paths (which set status +
-- have payment_status confirmed). Fires only on a direct status change to
-- completed; the payment-side auto-complete updates payment_status (not status)
-- and is validated by its own logic.
create or replace function public.enforce_two_gate_complete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    if not (public.jo_all_services_done(new.id) and new.payment_status = 'confirmed') then
      raise exception 'Cannot complete — every service must be done AND payment must be confirmed.'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists job_orders_zzz_enforce_complete on public.job_orders;
create trigger job_orders_zzz_enforce_complete before update of status on public.job_orders
  for each row execute function public.enforce_two_gate_complete();

-- ---------- 2) is_admin is owner-only (recreate the guard from 0093 + rule) ----------
create or replace function public.guard_broker_protected_fields()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_is_owner boolean;
  v_attempt  text[] := '{}';
  v_owner_ok boolean := coalesce(current_setting('ktc.allow_owner_change', true), '') = '1';
begin
  if auth.uid() is null then
    new.is_root_owner := old.is_root_owner;
    return new;
  end if;
  v_is_owner := coalesce((select is_owner from public.customers where user_id = auth.uid()), false);

  if not v_is_owner and new.staff_role is distinct from old.staff_role then
    v_attempt := v_attempt || 'staff_role';
    new.staff_role := old.staff_role;
  end if;

  if old.is_owner then
    if not v_is_owner then
      if new.is_owner is distinct from old.is_owner then v_attempt := v_attempt || 'is_owner'; end if;
      if new.is_admin is distinct from old.is_admin then v_attempt := v_attempt || 'is_admin'; end if;
      if new.status   is distinct from old.status   then v_attempt := v_attempt || 'status';   end if;
    end if;
    if not v_owner_ok then new.is_owner := old.is_owner; end if;
    new.is_admin   := old.is_admin;
    new.status     := old.status;
    new.decided_at := old.decided_at;
  end if;

  if not public.is_admin() then
    if new.is_owner is distinct from old.is_owner then v_attempt := v_attempt || 'is_owner'; end if;
    if new.is_admin is distinct from old.is_admin then v_attempt := v_attempt || 'is_admin'; end if;
    new.is_owner := old.is_owner;
    new.is_admin := old.is_admin;
    if not (old.status in ('rejected', 'approved') and new.status = 'pending') then
      if new.status is distinct from old.status then v_attempt := v_attempt || 'status'; end if;
      new.status     := old.status;
      new.decided_at := old.decided_at;
    end if;
  end if;

  -- Changing is_admin is OWNER-only (staff are owner-invite-only). Blocks a
  -- plain admin from minting/altering admins via a raw row update.
  if new.is_admin is distinct from old.is_admin and not v_is_owner then
    v_attempt := v_attempt || 'is_admin';
    new.is_admin := old.is_admin;
  end if;

  if not v_owner_ok then
    new.is_owner := old.is_owner;
  end if;
  new.is_root_owner := old.is_root_owner;

  if array_length(v_attempt, 1) is not null then
    perform public.log_security_event('protected_field_attempt', new.id,
      jsonb_build_object('fields', (select to_jsonb(array_agg(distinct f)) from unnest(v_attempt) f)));
  end if;
  return new;
end;
$$;

-- ---------- 3) recording an invoice requires a completed order ----------
create or replace function public.record_service_invoice(p_id uuid, p_invoice_no text, p_pad_no text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v   text := upper(regexp_replace(coalesce(p_invoice_no, ''), '\s', '', 'g'));
  pad text := regexp_replace(coalesce(p_pad_no, ''), '\s', '', 'g');
  m   text[];
  v_status text;
begin
  if not public.has_permission('record_invoice') then
    raise exception 'You don''t have permission to record invoices.';
  end if;
  select status into v_status from public.job_orders where id = p_id;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status <> 'completed' then
    raise exception 'An invoice can only be recorded on a completed order (this one is %).', v_status
      using errcode = 'check_violation';
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
end;
$$;

-- ---------- 4) submit_payment_proof refuses a held draft ----------
create or replace function public.submit_payment_proof(p_id uuid, p_path text, p_kind text default 'base')
returns void language plpgsql security definer set search_path = public as $$
declare v_row public.job_orders%rowtype;
begin
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then
    raise exception 'Invalid proof path.';
  end if;
  select * into v_row from public.job_orders
    where id = p_id and customer_id = public.current_broker_id() for update;
  if not found then raise exception 'Job order not found.'; end if;
  if v_row.status in ('cancelled','rejected','held') then
    raise exception 'This order is % — no payment is due yet.', v_row.status;
  end if;
  if p_kind = 'rps' then
    if v_row.rps_status <> 'needed' then raise exception 'No RPS charge is due on this order.'; end if;
    if v_row.rps_payment_status = 'confirmed' then raise exception 'The RPS payment is already confirmed.'; end if;
    update public.job_orders
       set rps_payment_status = 'submitted', rps_payment_proof_path = p_path,
           rps_payment_submitted_at = now(), rps_payment_note = null
     where id = p_id;
  else
    if v_row.payment_status = 'confirmed' then raise exception 'Payment for this order is already confirmed.'; end if;
    update public.job_orders
       set payment_status = 'submitted', payment_proof_path = p_path,
           payment_submitted_at = now(), payment_note = null
     where id = p_id;
  end if;
end;
$$;
revoke all on function public.submit_payment_proof(uuid, text, text) from public, anon;
grant execute on function public.submit_payment_proof(uuid, text, text) to authenticated;

-- ---------- 5) exactly one root owner (DB-enforced) ----------
create unique index if not exists customers_one_root_owner
  on public.customers (is_root_owner) where is_root_owner;

-- ---------- 6) security alerts go to the ROOT owner, deterministically ----------
-- (recreate check_ops_alerts from 0092, recipient = root owner)
create or replace function public.check_ops_alerts()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cron_fails int; v_out_fails int; v_errs int; v_sec int; v_grants int;
  v_email text; v_name text; v_body text := '';
  v_send boolean := false;
begin
  perform public.reconcile_outbound();

  select count(*) into v_cron_fails
    from cron.job_run_details d join cron.job j on j.jobid = d.jobid
    where d.start_time > now() - interval '70 minutes'
      and d.status = 'failed'
      and j.jobname <> 'ops-watchdog';
  select count(*) into v_out_fails
    from public.outbound_requests
    where created_at > now() - interval '70 minutes'
      and (status_code >= 400 or error_msg is not null);
  select count(*) into v_errs
    from public.app_errors where created_at > now() - interval '20 minutes';
  select count(*) into v_sec
    from public.security_events where created_at > now() - interval '20 minutes';
  select count(*) into v_grants
    from public.security_events
    where created_at > now() - interval '20 minutes' and kind = 'privilege_granted';

  if v_sec > 0 and not exists (select 1 from public.ops_alerts
      where key = 'security' and last_sent > now() - interval '1 hour') then
    if v_grants > 0 then
      v_body := v_body || '&bull; <strong>🚨 ' || v_grants || ' privilege GRANT(s)</strong> — an account just gained admin / owner / a staff role. If this wasn''t you, treat it as a breach. ';
    end if;
    v_body := v_body || '&bull; <strong>' || v_sec || ' security event(s)</strong> (grants / blocked escalation / role-gate edits). Review in Settings &rarr; System health.<br/>';
    insert into public.ops_alerts (key, last_sent) values ('security', now())
      on conflict (key) do update set last_sent = now();
    v_send := true;
  end if;
  if v_cron_fails > 0 and not exists (select 1 from public.ops_alerts
      where key = 'ops-cron' and last_sent > now() - interval '6 hours') then
    v_body := v_body || '&bull; <strong>' || v_cron_fails || ' failed cron run(s)</strong> (expiry / mirror / archive / carry-over)<br/>';
    insert into public.ops_alerts (key, last_sent) values ('ops-cron', now())
      on conflict (key) do update set last_sent = now();
    v_send := true;
  end if;
  if v_out_fails > 0 and not exists (select 1 from public.ops_alerts
      where key = 'ops-outbound' and last_sent > now() - interval '6 hours') then
    v_body := v_body || '&bull; <strong>' || v_out_fails || ' failed outbound call(s)</strong> (emails / BOC mirror)<br/>';
    insert into public.ops_alerts (key, last_sent) values ('ops-outbound', now())
      on conflict (key) do update set last_sent = now();
    v_send := true;
  end if;
  if v_errs > 0 and not exists (select 1 from public.ops_alerts
      where key = 'client-errors' and last_sent > now() - interval '6 hours') then
    v_body := v_body || '&bull; <strong>' || v_errs || ' client error(s)</strong> in the last 20 minutes<br/>';
    insert into public.ops_alerts (key, last_sent) values ('client-errors', now())
      on conflict (key) do update set last_sent = now();
    v_send := true;
  end if;

  if v_send then
    select email, full_name into v_email, v_name
      from public.customers where is_root_owner order by created_at limit 1;
    if v_email is null then
      select email, full_name into v_email, v_name
        from public.customers where is_owner order by created_at limit 1;
    end if;
    perform public.send_portal_email(
      v_email, v_name,
      case when v_sec > 0 then '🚨 KTC portal security alert' else 'KTC portal watchdog: something needs a look' end,
      case when v_sec > 0 then 'Security alert' else 'System health alert' end,
      'The portal watchdog found:<br/><br/>' || v_body || '<br/>Details are in Settings &rarr; System health.',
      'https://portal.ktcterminal.com/admin/settings', 'Open System health');
  end if;

  delete from public.app_errors        where created_at < now() - interval '30 days';
  delete from public.outbound_requests where created_at < now() - interval '30 days';
  delete from public.security_events   where created_at < now() - interval '90 days';
  begin
    delete from cron.job_run_details where end_time < now() - interval '14 days';
  exception when others then null;
  end;
end;
$$;
revoke all on function public.check_ops_alerts() from public, anon, authenticated;
