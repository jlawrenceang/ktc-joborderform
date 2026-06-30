-- ============================================================
-- 0231 - SMS activation safety
--
-- Keep the dormant SMS scaffold safe to activate:
--   * SMS only sends for event types whose admin channel is sms/both.
--   * Customer opt-out and phone normalization stay enforced in the trigger.
--   * Vault rows still arm/disarm the transport.
-- ============================================================

create or replace function public.sms_on_notification()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_secret text;
  v_phone text;
  v_optout boolean;
  v_to text;
  v_event text;
  v_channel text;
begin
  -- Map concrete notification kinds to the owner-managed routing table.
  v_event := case
    when new.kind in ('on_hold', 'rejected', 'completed') then 'jo_status_change'
    when new.kind = 'payment_confirmed' then 'payment_confirmed'
    when new.kind = 'payment_rejected' then 'payment_rejected'
    when new.kind in ('release_payable', 'release_on_hold', 'release_rejected', 'release_released') then 'release_status'
    else null
  end;
  if v_event is null then return new; end if;

  -- Respect Settings -> Operations -> Notifications. Default rows are email,
  -- so merely arming Vault does not start texting customers.
  v_channel := public.notification_channel(v_event);
  if v_channel not in ('sms', 'both') then return new; end if;

  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'sms_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'sms_secret';
  if v_url is null or v_secret is null then return new; end if;

  select contact_number, sms_opt_out into v_phone, v_optout
    from public.customers where id = new.customer_id;
  if coalesce(v_optout, false) then return new; end if;
  v_to := public.ph_e164(v_phone);
  if v_to is null then return new; end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object('x-sms-secret', v_secret, 'Content-Type', 'application/json'),
    body := jsonb_build_object(
      'to', jsonb_build_array(v_to),
      'message', left('KTC Online Portal: ' || coalesce(new.title, 'You have an update.'), 320)
    )
  );
  return new;
end $$;

revoke all on function public.sms_on_notification() from public, anon, authenticated;

drop trigger if exists notifications_sms on public.notifications;
create trigger notifications_sms after insert on public.notifications
  for each row execute function public.sms_on_notification();

notify pgrst, 'reload schema';
