-- ============================================================
-- 0092 — alert the owner on any privilege GRANT, by any path (owner, 2026-06-16)
--
-- 0046 blocks + alerts on privilege-escalation ATTEMPTS via the app. This adds
-- the other side: log + alert whenever an account actually GAINS admin / owner /
-- a staff role — including a direct DB write (e.g. a leaked service-role key)
-- that bypasses the auth-context guard. The owner gets an email within 15 min.
-- Legit grants (create_staff, owner action) also alert — by design, so an
-- illicit one can never hide among them, and a real one is easy to confirm.
-- ============================================================

-- 1) Log every privilege grant (fires regardless of who did it / auth context).
create or replace function public.audit_privilege_grant()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (new.is_owner and not coalesce(old.is_owner, false))
     or (new.is_admin and not coalesce(old.is_admin, false))
     or (new.staff_role is not null and new.staff_role is distinct from old.staff_role) then
    insert into public.security_events (kind, actor, target, detail)
    values ('privilege_granted', auth.uid(), new.id,
      jsonb_build_object(
        'email', new.email,
        'is_owner', new.is_owner,
        'is_admin', new.is_admin,
        'staff_role', new.staff_role,
        'by_db_context', auth.uid() is null  -- true = direct DB write, no app session (red flag)
      ));
  end if;
  return new;
end;
$$;
drop trigger if exists customers_audit_privilege on public.customers;
create trigger customers_audit_privilege after update on public.customers
  for each row execute function public.audit_privilege_grant();

-- 2) Widen the watchdog: alert on EVERY security event in the window (privilege
--    grants, blocked escalation attempts, role-gate edits) — not just blocked
--    attempts. Per-category 1h dedupe still prevents spam during config.
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
  -- ANY security event now (was: only protected_field_attempt)
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
      from public.customers where is_owner limit 1;
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
