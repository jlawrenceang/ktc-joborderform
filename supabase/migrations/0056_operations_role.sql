-- ============================================================
-- 0056 — operations staff role (the ops floor; checker sits under it)
--
-- Adds the 'operations' role. Operations is the broad ops-floor role:
-- runs the job-order queue (view / file / process / confirm X-ray), manages
-- consignees, and (in later migrations) maintains the vessel schedule and acts
-- as the RPS assessor. The checker role sits UNDER operations — operations
-- therefore also holds 'confirm_xray'.
--
-- Roles are DATA: has_permission() already resolves any staff_role generically
-- against role_permissions, so this migration is just (1) widen the role
-- whitelists, (2) seed the operations gates, (3) let create_staff mint one.
-- Operations is NOT is_admin (like cashier/checker) — it works through the
-- gated policies/RPCs, never the broad admin policies. The owner bypasses all
-- gates (failsafe, unchanged).
--
-- NOTE: file/process today are is_admin-gated (see 0035 + the job_orders
-- "admin updates job orders" policy). A follow-up migration adds permission-
-- gated process_job_order / file-on-behalf RPCs so operations can act without
-- is_admin and without a broad UPDATE policy that would leak the invoice
-- fields. Until then operations gets view + confirm_xray (the checker duties,
-- already routed through record_xray()).
-- ============================================================

-- 1) Widen the role whitelists on both tables.
alter table public.customers drop constraint if exists customers_staff_role_check;
alter table public.customers add constraint customers_staff_role_check
  check (staff_role in ('admin','cashier','checker','operations'));

alter table public.role_permissions drop constraint if exists role_permissions_role_check;
alter table public.role_permissions add constraint role_permissions_role_check
  check (role in ('admin','cashier','checker','operations'));

-- 2) Seed operations' default gates — the full ops floor, no money/admin.
--    (matches the 10 live permissions: view/file/process/confirm_xray/
--     record_invoice/review_payments/manage_approvals/manage_customers/
--     manage_consignees/manage_pricing)
insert into public.role_permissions (role, permission, allowed) values
  ('operations', 'view_job_orders',    true),
  ('operations', 'file_job_orders',    true),
  ('operations', 'process_job_orders', true),
  ('operations', 'confirm_xray',       true),   -- checker sits under operations
  ('operations', 'manage_consignees',  true),
  ('operations', 'record_invoice',     false),
  ('operations', 'review_payments',    false),
  ('operations', 'manage_approvals',   false),
  ('operations', 'manage_customers',   false),
  ('operations', 'manage_pricing',     false)
on conflict (role, permission) do nothing;

-- 3) create_staff accepts 'operations'. Body unchanged except the role
--    whitelist; is_admin = (p_role = 'admin') already leaves operations
--    non-admin.
create or replace function public.create_staff(p_username text, p_password text, p_full_name text, p_role text default 'admin')
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
  if p_role not in ('admin','cashier','checker','operations') then
    raise exception 'Unknown role %', p_role;
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
  set is_admin = (p_role = 'admin'),
      staff_role = p_role,
      status = 'approved',
      full_name = p_full_name,
      decided_at = now()
  where user_id = v_id;

  return v_email;
end;
$$;

revoke all on function public.create_staff(text, text, text, text) from public, anon;
grant execute on function public.create_staff(text, text, text, text) to authenticated;
