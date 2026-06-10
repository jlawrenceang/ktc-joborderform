-- ============================================================
-- 0025 — add a copyright line to the approval-email footer.
-- (The confirm-signup template is updated separately via
-- scripts/set-auth-email-template.mjs.)
-- ============================================================

create or replace function public.send_broker_approved_email()
returns trigger language plpgsql security definer set search_path = public, vault, net as $fn$
declare
  v_key   text;
  v_from  text;
  v_name  text;
  v_html  text;
  v_url   text := 'https://portal.ktcterminal.com';
begin
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
