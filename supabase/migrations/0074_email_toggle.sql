-- ============================================================
-- 0074 — owner-controlled email on/off switch (owner, 2026-06-15)
--
-- The owner wants to SUSPEND customer notification emails for now and flip
-- them back on quickly from Settings. We add a global flag `emails_enabled`
-- (default FALSE = suspended) and gate the two CUSTOMER-facing email triggers
-- on it:
--   * send_broker_approved_email   (account approved)
--   * send_job_order_status_email  (on_hold / rejected / payment rejected)
--
-- The shared helper send_portal_email is deliberately NOT gated: the owner
-- watchdog / security alerts (0045/0046) also use it and must always fire,
-- regardless of the customer-email switch.
-- ============================================================

create table if not exists public.app_settings (
  key        text primary key,
  bool_value boolean,
  updated_at timestamptz not null default now()
);
alter table public.app_settings enable row level security;
drop policy if exists "read app settings" on public.app_settings;
create policy "read app settings" on public.app_settings
  for select to authenticated using (public.is_admin());
drop policy if exists "owner writes app settings" on public.app_settings;
create policy "owner writes app settings" on public.app_settings
  for all to authenticated
  using (coalesce((select c.is_owner from public.customers c where c.user_id = auth.uid()), false))
  with check (coalesce((select c.is_owner from public.customers c where c.user_id = auth.uid()), false));

-- Suspended for now — owner flips this on in Settings when ready.
insert into public.app_settings (key, bool_value) values ('emails_enabled', false)
on conflict (key) do nothing;

-- Read helper (SECURITY DEFINER so the triggers read it past RLS). Missing /
-- null row = OFF, so a fresh install never emails until the owner opts in.
create or replace function public.emails_enabled()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select bool_value from public.app_settings where key = 'emails_enabled'), false);
$$;
revoke all on function public.emails_enabled() from public, anon;
grant execute on function public.emails_enabled() to authenticated;

-- ---- gate: account-approved email (body copied from 0025 + the guard) ----
create or replace function public.send_broker_approved_email()
returns trigger language plpgsql security definer set search_path = public, vault, net as $fn$
declare
  v_key   text;
  v_from  text;
  v_name  text;
  v_html  text;
  v_url   text := 'https://portal.ktcterminal.com';
begin
  if not public.emails_enabled() then return new; end if;  -- owner switch (0074)
  if new.status <> 'approved' or old.status is not distinct from new.status then
    return new;
  end if;
  if new.email is null or length(trim(new.email)) = 0 then
    return new;
  end if;

  begin
    select decrypted_secret into v_key  from vault.decrypted_secrets where name = 'resend_api_key';
    select decrypted_secret into v_from from vault.decrypted_secrets where name = 'resend_from';
  exception when others then
    v_key := null;
  end;

  if v_key is null then
    raise notice 'send_broker_approved_email: no resend_api_key in vault — skipping email for %', new.email;
    return new;
  end if;
  if v_from is null then
    v_from := 'KTC Container Terminal <noreply@ktcterminal.com>';
  end if;

  v_name := coalesce(nullif(trim(new.full_name), ''), 'there');

  v_html := $html$<table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f2f5;padding:32px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <tr><td align="center">
    <table width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:16px;border:1px solid #e6e7ea;overflow:hidden;">
      <tr><td style="padding:28px 32px 8px;">
        <img src="https://portal.ktcterminal.com/ktc-logo.png" alt="KTC Container Terminal Corp" height="44" style="display:block;border:0;" />
      </td></tr>
      <tr><td style="padding:8px 32px 0;">
        <h1 style="margin:0;font-size:21px;font-weight:600;letter-spacing:-0.02em;color:#1a1c1f;">Your account is approved &#127881;</h1>
        <p style="margin:12px 0 0;font-size:14px;line-height:1.6;color:#4b4f56;">
          Hi {{BROKER_NAME}}, good news &mdash; a KTC admin has reviewed and <strong>approved</strong> your KTC Online Portal account. You can now sign in and submit Job Orders for terminal services (X-ray, DEA exam, OOG stripping, gate/yard requests).
        </p>
      </td></tr>
      <tr><td style="padding:24px 32px 8px;">
        <a href="{{PORTAL_URL}}" style="display:inline-block;background:#F26A21;color:#ffffff;text-decoration:none;font-size:14px;font-weight:600;padding:12px 22px;border-radius:10px;">Go to the KTC Online Portal</a>
      </td></tr>
      <tr><td style="padding:8px 32px 28px;">
        <p style="margin:14px 0 0;font-size:12px;line-height:1.6;color:#8a8f98;">
          If the button doesn't work, copy and paste this link into your browser:<br/>
          <a href="{{PORTAL_URL}}" style="color:#D6321E;word-break:break-all;">{{PORTAL_URL}}</a>
        </p>
        <p style="margin:16px 0 0;font-size:12px;line-height:1.6;color:#8a8f98;">
          Sign in with the email and password you registered with. If you have any questions, just reply to this email.
        </p>
      </td></tr>
    </table>
    <p style="max-width:480px;margin:16px auto 0;font-size:11px;color:#a0a4ab;text-align:center;">&copy; 2026 KTC Container Terminal Corp. &middot; portal.ktcterminal.com</p>
  </td></tr>
</table>$html$;

  v_html := replace(v_html, '{{BROKER_NAME}}', v_name);
  v_html := replace(v_html, '{{PORTAL_URL}}', v_url);

  begin
    perform net.http_post(
      url     := 'https://api.resend.com/emails',
      headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
      body    := jsonb_build_object(
        'from',    v_from,
        'to',      new.email,
        'subject', 'Your KTC Online Portal account is approved',
        'html',    v_html
      )
    );
  exception when others then
    raise notice 'send_broker_approved_email: http_post failed for %: %', new.email, sqlerrm;
  end;

  return new;
end;
$fn$;

-- ---- gate: JO status / payment emails (body copied from 0042 + the guard) ----
create or replace function public.send_job_order_status_email()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_email text; v_name text;
  v_jo text := coalesce(new.jo_number, 'your job order');
begin
  if not public.emails_enabled() then return new; end if;  -- owner switch (0074)

  -- One lookup serves whichever branches fire below.
  select email, full_name into v_email, v_name
    from public.customers where id = new.customer_id;

  -- Action-required status transitions only; never on insert or same-status updates.
  if new.status in ('on_hold','rejected') and old.status is distinct from new.status then
    if new.status = 'on_hold' then
      perform public.send_portal_email(
        v_email, v_name,
        'Action needed on ' || v_jo || ' — information required',
        'We need a little more information',
        'Your job order <strong>' || v_jo || '</strong> is on hold. A KTC admin left this note:'
          || '<br/><br/><em>' || coalesce(new.admin_note, '(no note)') || '</em><br/><br/>'
          || 'Open the portal to update the order and resubmit it — processing resumes as soon as you do.',
        'https://portal.ktcterminal.com/job-orders', 'Open My Job Orders');
    else
      perform public.send_portal_email(
        v_email, v_name,
        v_jo || ' was rejected' || case when new.rejected_recoverable then ' — you can fix and resubmit' else '' end,
        'Job order rejected',
        'Your job order <strong>' || v_jo || '</strong> was rejected. Reason from KTC:'
          || '<br/><br/><em>' || coalesce(new.admin_note, '(no note)') || '</em><br/><br/>'
          || case when new.rejected_recoverable
               then 'You can fix the issue and <strong>resubmit the same order</strong> from the portal.'
               else 'This order is closed — if needed, please file a new job order from the portal.'
             end,
        'https://portal.ktcterminal.com/job-orders', 'Open My Job Orders');
    end if;
  end if;

  -- G8: rejected payment proof — the customer must re-upload.
  if new.payment_status = 'rejected' and old.payment_status is distinct from new.payment_status then
    perform public.send_portal_email(
      v_email, v_name,
      'Payment proof for ' || v_jo || ' needs another look',
      'Payment proof rejected',
      'The payment slip you uploaded for <strong>' || v_jo || '</strong> couldn''t be accepted. Note from KTC:'
        || '<br/><br/><em>' || coalesce(new.payment_note, '(no note)') || '</em><br/><br/>'
        || 'Please check the note and upload a corrected slip — or settle at the KTC cashier as usual.',
      'https://portal.ktcterminal.com/job-order/' || new.id || '/pay', 'Fix my payment');
  end if;

  return new;
end;
$fn$;
