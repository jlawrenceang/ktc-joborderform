-- ============================================================
-- 0122 — owner-only "send a test email" RPC (2026-06-20).
-- Lets the owner send a real test of the branded portal email templates to any
-- address, to confirm rendering + the Resend pipeline. Reuses send_portal_email
-- (0042/0045) so there's no template drift, and bypasses the emails_enabled
-- switch (0074) since this is an explicit owner test. Returns 'sent'.
-- ============================================================
create or replace function public.owner_send_test_email(
  p_to       text,
  p_template text default 'notification'
)
returns text language plpgsql security definer set search_path = public, vault, net as $$
declare v_subject text; v_head text; v_body text; v_cta text;
        v_url text := 'https://portal.ktcterminal.com/';
begin
  if not coalesce((select is_owner from public.customers where user_id = auth.uid()), false) then
    raise exception 'Only the owner can send test emails' using errcode = 'insufficient_privilege';
  end if;
  if p_to is null or btrim(p_to) = '' or position('@' in p_to) = 0 then
    raise exception 'Enter a valid recipient email address.';
  end if;
  if not exists (select 1 from vault.decrypted_secrets where name = 'resend_api_key') then
    raise exception 'Email is not configured yet (missing Vault resend_api_key).';
  end if;

  case p_template
    when 'approved' then
      v_subject := '[TEST] Your KTC account is approved';
      v_head := 'Account approved';
      v_body := 'your KTC Online Portal account has been approved — you can now file Job Orders. (This is a TEST email.)';
      v_cta := 'Open the portal';
    when 'on_hold' then
      v_subject := '[TEST] Your Job Order needs information';
      v_head := 'Action needed';
      v_body := 'one of your Job Orders is on hold and needs more information. Please log in to review and respond. (This is a TEST email.)';
      v_cta := 'View order';
    when 'rejected' then
      v_subject := '[TEST] Update on your Job Order';
      v_head := 'Job Order update';
      v_body := 'there was an update on one of your Job Orders that needs your attention. Please log in to view the details. (This is a TEST email.)';
      v_cta := 'View order';
    when 'payment' then
      v_subject := '[TEST] A payment needs attention';
      v_head := 'Payment update';
      v_body := 'there is an update on a payment for one of your Job Orders. Please log in to review it. (This is a TEST email.)';
      v_cta := 'View payment';
    else -- 'notification' — the live consolidated nudge customers actually receive
      v_subject := '[TEST] You have a notification in the KTC portal';
      v_head := 'Action needed';
      v_body := 'this is a TEST of the KTC portal email template. In real use you would have a notification needing your attention — just log in and it will be waiting. No action required for this test.';
      v_cta := 'Open the portal';
  end case;

  perform public.send_portal_email(p_to, 'there', v_subject, v_head, v_body, v_url, v_cta);
  return 'sent';
end $$;

revoke all on function public.owner_send_test_email(text, text) from public, anon;
grant execute on function public.owner_send_test_email(text, text) to authenticated;
