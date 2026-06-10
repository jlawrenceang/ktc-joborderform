-- ============================================================
-- 0032 — security-review hardening (2026-06-11 review).
--
-- 1) Storage upload constraints. The valid-ID (and consignee-doc) uploads were
--    only validated by the browser's accept= attribute. Enforce server-side:
--    10 MB max + image/PDF MIME types only, at the bucket level.
-- 2) create_staff password parity. GoTrue's password policy was raised to
--    8+ chars with a letter and a digit (Management API), but create_staff
--    writes encrypted_password directly via crypt(), bypassing GoTrue — so it
--    must enforce the same rule itself. Function otherwise identical to 0021's.
-- ============================================================

-- 1) Bucket constraints (applies to NEW uploads; existing objects unaffected).
update storage.buckets
set file_size_limit = 10485760, -- 10 MB
    allowed_mime_types = array[
      'image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif',
      'application/pdf'
    ]
where id in ('valid-ids', 'consignee-docs');

-- 2) create_staff: same password policy as GoTrue (8+ chars, ≥1 letter, ≥1 digit).
create or replace function public.create_staff(p_username text, p_password text, p_full_name text)
returns text language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  v_uid   uuid := auth.uid();
  v_email text := lower(trim(p_username)) || '@ktc-staff.local';
  v_id    uuid := gen_random_uuid();
begin
  if v_uid is not null
     and not coalesce((select is_owner from public.customers where user_id = v_uid), false) then
    raise exception 'Only the owner can create staff';
  end if;
  if length(coalesce(trim(p_username), '')) < 3 then raise exception 'Username must be at least 3 characters'; end if;
  if length(coalesce(p_password, '')) < 8
     or p_password !~ '[A-Za-z]' or p_password !~ '[0-9]' then
    raise exception 'Password must be at least 8 characters and include a letter and a number';
  end if;
  if exists (select 1 from auth.users where email = v_email) then
    raise exception 'That username is already taken';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, is_sso_user,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
    crypt(p_password, gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', p_full_name, 'username', lower(trim(p_username))),
    false,
    '', '', '', '', '', '', '', ''
  );

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, created_at, updated_at, last_sign_in_at
  ) values (
    v_id::text, v_id,
    jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now()
  );

  update public.customers
  set is_admin = true, status = 'approved', full_name = p_full_name, decided_at = now()
  where user_id = v_id;

  return v_email;
end;
$$;
