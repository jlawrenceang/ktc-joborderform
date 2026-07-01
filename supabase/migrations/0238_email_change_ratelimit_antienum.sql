-- ============================================================
-- 0238 — email-change rate-limit + anti-enumeration + drop dead policy (CX-10 / CX-13)
--
-- From the 2026-07-01 review LOW batch (docs/audits/2026-07-02-codex-0701-batch-review.md):
--   CX-10  request_customer_email_change had (a) no throttle — an authenticated/abusive
--          session could email-bomb arbitrary addresses with KTC-branded confirmations,
--          and (b) a distinct "that email already has an account" error that let a caller
--          probe the account roster (enumeration). Add a per-customer rate limit (max 3
--          requests / rolling hour) and, for a taken email, return the SAME generic 'sent'
--          outcome (no request row, no mail) instead of a distinct error.
--   CX-13  Drop the dead SELECT policy on customer_email_change_requests — the table-level
--          grant is revoked from authenticated, so the policy could never apply.
--
-- Recreated from 0237 (the CX-02 owner-email lock is preserved) with ONLY the two CX-10
-- additions. confirm_customer_email_change is unchanged.
-- ============================================================

-- CX-13: the SELECT policy is dead (grant already revoked from authenticated) — remove it.
drop policy if exists "customers read own email change requests" on public.customer_email_change_requests;

create or replace function public.request_customer_email_change(
  p_new_email text,
  p_redirect_base text default 'https://portal.ktcterminal.com'
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_customer public.customers%rowtype;
  v_new text := lower(trim(coalesce(p_new_email, '')));
  v_old text;
  v_recent int;
  v_token text;
  v_hash text;
  v_base text;
  v_url text;
begin
  select * into v_customer from public.customers where user_id = auth.uid();
  if v_customer.id is null then
    raise exception 'Customer account not found.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(v_customer.email, '') like '%@ktc-staff.local' then
    raise exception 'Staff emails are managed by the owner.' using errcode = 'insufficient_privilege';
  end if;

  v_old := lower(trim(coalesce(v_customer.email, auth.email(), '')));

  -- CX-02 owner-email lock (0237): block changing TO or FROM an owner / root-owner email.
  if v_new = 'jlawrenceang@gmail.com'
     or v_old = 'jlawrenceang@gmail.com'
     or exists (select 1 from public.customers c
                 where (c.is_owner or c.is_root_owner)
                   and lower(coalesce(c.email, '')) in (v_new, v_old)) then
    raise exception 'The owner account email is protected and cannot be changed here.'
      using errcode = 'insufficient_privilege';
  end if;

  if v_new !~* '^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$' then
    raise exception 'Enter a valid new email address.' using errcode = 'check_violation';
  end if;
  if v_new = v_old then
    raise exception 'That is already your email.' using errcode = 'check_violation';
  end if;

  -- CX-10 rate limit: at most 3 change requests per customer per rolling hour, so a
  -- compromised/abusive session can't email-bomb arbitrary addresses with KTC mail. These
  -- reveal only the CALLER's own request rate, not anyone else's account state.
  select count(*) into v_recent
    from public.customer_email_change_requests
   where customer_id = v_customer.id
     and created_at > now() - interval '1 hour';
  if v_recent >= 3 then
    raise exception 'Too many email-change requests. Please wait a while before trying again.';
  end if;

  -- CX-10 anti-enumeration: if the target email already belongs to another account, do NOT
  -- reveal it (a distinct error would let an authenticated caller probe the roster). Return
  -- the same generic outcome, but create no request row and send no mail. The taken email is
  -- never emailed, so this is not an abuse vector; confirm-side uniqueness (0237) still holds.
  if exists (select 1 from auth.users where lower(email) = v_new and id <> auth.uid())
     or exists (select 1 from public.customers where lower(email) = v_new and user_id <> auth.uid()) then
    return 'sent';
  end if;

  update public.customer_email_change_requests
     set superseded_at = now()
   where customer_id = v_customer.id
     and confirmed_at is null
     and superseded_at is null;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  v_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');
  v_base := case
    when trim(coalesce(p_redirect_base, '')) = 'https://portal.ktcterminal.com'
      then 'https://portal.ktcterminal.com'
    when trim(coalesce(p_redirect_base, '')) like 'http://localhost:%'
      then rtrim(trim(p_redirect_base), '/')
    when trim(coalesce(p_redirect_base, '')) like 'http://127.0.0.1:%'
      then rtrim(trim(p_redirect_base), '/')
    else 'https://portal.ktcterminal.com'
  end;
  v_url := v_base || '/email-change-confirm?token=' || v_token;

  insert into public.customer_email_change_requests(customer_id, user_id, old_email, new_email, token_hash)
  values (v_customer.id, auth.uid(), v_old, v_new, v_hash);

  perform public.send_portal_email(
    v_new,
    coalesce(v_customer.full_name, 'there'),
    'Confirm your new KTC portal email',
    'Confirm your new email',
    'please confirm that this email address should be used for your KTC Online Portal account. Your account email will not change until you confirm this link.',
    v_url,
    'Confirm new email'
  );

  perform public.send_portal_email(
    v_old,
    coalesce(v_customer.full_name, 'there'),
    'Security notice: KTC portal email change requested',
    'Email change requested',
    'a request was made to change your KTC Online Portal email address. If this was you, no action is needed. If this was not you, contact KTC support immediately or file a support report in the portal.',
    'https://portal.ktcterminal.com/support',
    'Contact support'
  );

  return 'sent';
end;
$$;

revoke all on function public.request_customer_email_change(text, text) from public, anon;
grant execute on function public.request_customer_email_change(text, text) to authenticated;
