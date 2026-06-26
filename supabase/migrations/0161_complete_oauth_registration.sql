-- ============================================================
-- 0161 — complete OAuth (Google) registration
--
-- A Google sign-in creates an auth user + customer row (via handle_new_user)
-- but DOESN'T collect the contact number or the Customer Agreement consent that
-- the email/password sign-up form gathers. This RPC records both on the caller's
-- own customer row, server-side (so the consent version is recorded, not spoofed
-- field-by-field through a client table UPDATE). Called once from the
-- "Finish registration" gate (ProtectedRoute) after a Google sign-up.
-- ============================================================

create or replace function public.complete_oauth_registration(p_contact text, p_version text)
returns void language plpgsql security definer set search_path = public as $$
declare v_cust uuid := public.current_broker_id();
begin
  if v_cust is null then raise exception 'No customer account is linked to this sign-in.'; end if;
  if coalesce(trim(p_contact), '') = '' then raise exception 'A contact number is required.'; end if;
  if coalesce(trim(p_version), '') = '' then raise exception 'Agreement version is required.'; end if;
  update public.customers
     set contact_number         = trim(p_contact),
         irr_version             = p_version, irr_accepted_at      = now(),
         terms_version           = p_version, terms_accepted_at    = now(),
         privacy_consent_version = p_version, privacy_consented_at = now()
   where id = v_cust;
  if not found then raise exception 'Customer account not found.'; end if;
end;
$$;

-- Definer function: lock execute down to authenticated only.
revoke all on function public.complete_oauth_registration(text, text) from public, anon;
grant execute on function public.complete_oauth_registration(text, text) to authenticated;
