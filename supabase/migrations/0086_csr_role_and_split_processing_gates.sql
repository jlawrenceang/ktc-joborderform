-- ============================================================
-- 0086 — CSR role + split processing gates + gated transition RPC (owner, 2026-06-16)
--
-- Two changes to the staff model:
--
-- 1) New 'csr' role — the customer-service desk: files Job Orders for customers
--    and works the support inbox, but does NOT change an order's workflow status
--    (they relay messages, not decisions). view + file_job_orders + manage_support.
--
-- 2) The single 'process_job_orders' gate is SPLIT for the explicit staff
--    transitions so each stage is independently assignable in Roles & Gates and
--    enforced server-side:
--      accept_orders       submitted/on_hold -> processing   (Operations, Admin)
--      hold_reject_orders  -> on_hold / rejected              (Operations, Cashier, Admin)
--      complete_orders     -> completed                       (Operations, Cashier, Admin)
--    `process_job_orders` STAYS for the internal paths (DEA/OOG service-done,
--    requeue, archive, restore) — unchanged.
--
--    Completion is TWO-GATED: an order can only reach 'completed' when every
--    service line is done AND payment_status = 'confirmed' (whoever does the
--    last of the two triggers it). Enforced here in staff_transition_order; the
--    auto-complete paths adopt jo_ready_to_complete() in 0087.
-- ============================================================

-- 1) Widen the role whitelists to include 'csr'.
alter table public.customers drop constraint if exists customers_staff_role_check;
alter table public.customers add constraint customers_staff_role_check
  check (staff_role in ('admin','cashier','checker','operations','csr'));

alter table public.role_permissions drop constraint if exists role_permissions_role_check;
alter table public.role_permissions add constraint role_permissions_role_check
  check (role in ('admin','cashier','checker','operations','csr'));

-- 2) Seed the split-gate permissions for every existing role.
insert into public.role_permissions (role, permission, allowed) values
  ('admin',      'accept_orders',      true),
  ('admin',      'complete_orders',    true),
  ('admin',      'hold_reject_orders', true),
  ('operations', 'accept_orders',      true),
  ('operations', 'complete_orders',    true),
  ('operations', 'hold_reject_orders', true),
  ('cashier',    'accept_orders',      false),
  ('cashier',    'complete_orders',    true),   -- completes once payment is confirmed
  ('cashier',    'hold_reject_orders', true),
  ('checker',    'accept_orders',      false),
  ('checker',    'complete_orders',    false),
  ('checker',    'hold_reject_orders', false)
on conflict (role, permission) do nothing;

-- 3) Seed the 'csr' role — file + inbox + view only.
insert into public.role_permissions (role, permission, allowed) values
  ('csr', 'view_job_orders',        true),
  ('csr', 'file_job_orders',        true),
  ('csr', 'manage_support',         true),
  ('csr', 'accept_orders',          false),
  ('csr', 'complete_orders',        false),
  ('csr', 'hold_reject_orders',     false),
  ('csr', 'process_job_orders',     false),
  ('csr', 'confirm_xray',           false),
  ('csr', 'assess_rps',             false),
  ('csr', 'review_payments',        false),
  ('csr', 'record_invoice',         false),
  ('csr', 'manage_approvals',       false),
  ('csr', 'manage_customers',       false),
  ('csr', 'manage_consignees',      false),
  ('csr', 'manage_pricing',         false),
  ('csr', 'manage_vessel_schedule', false)
on conflict (role, permission) do nothing;

-- 3b) All customer communication funnels through CSR — Operations no longer
--     holds the support-inbox gate (0083 had granted it). Only CSR + Admin/Owner.
update public.role_permissions set allowed = false
  where role = 'operations' and permission = 'manage_support';

-- 4) create_staff accepts 'csr'.
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
  if p_role not in ('admin','cashier','checker','operations','csr') then
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

-- 5) Two-gate completion readiness: all services done AND payment confirmed.
create or replace function public.jo_ready_to_complete(p_jo uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.jo_all_services_done(p_jo)
     and (select payment_status from public.job_orders where id = p_jo) = 'confirmed';
$$;

-- 6) Gated staff transition RPC — replaces the admin-only direct UPDATE for the
--    explicit accept / hold / reject / complete actions.
create or replace function public.staff_transition_order(
  p_id          uuid,
  p_status      text,
  p_note        text    default null,
  p_recoverable boolean default null
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cur  text;
  v_gate text := case p_status
    when 'processing' then 'accept_orders'
    when 'completed'  then 'complete_orders'
    when 'on_hold'    then 'hold_reject_orders'
    when 'rejected'   then 'hold_reject_orders'
    else null end;
begin
  if v_gate is null then
    raise exception 'Unsupported transition to %.', p_status;
  end if;
  if not public.has_permission(v_gate) then
    raise exception 'You don''t have permission for this action.';
  end if;

  select status into v_cur from public.job_orders where id = p_id for update;
  if not found then raise exception 'Job order not found.'; end if;

  if p_status = 'processing' and v_cur not in ('submitted','on_hold') then
    raise exception 'Only a submitted or on-hold order can be accepted.';
  elsif p_status in ('on_hold','rejected') and v_cur not in ('submitted','processing','on_hold') then
    raise exception 'This order can''t be held or rejected now.';
  elsif p_status = 'completed' then
    if v_cur not in ('submitted','processing','on_hold') then
      raise exception 'Only an open order can be completed.';
    end if;
    if not public.jo_all_services_done(p_id) then
      raise exception 'Can''t complete yet — not all services (e.g. X-ray) are done.';
    end if;
    if (select payment_status from public.job_orders where id = p_id) is distinct from 'confirmed' then
      raise exception 'Can''t complete yet — payment is not confirmed.';
    end if;
  end if;

  update public.job_orders
  set status = p_status,
      admin_note = coalesce(p_note, admin_note),
      rejected_recoverable = case when p_status = 'rejected'
        then coalesce(p_recoverable, rejected_recoverable) else rejected_recoverable end
  where id = p_id;
end;
$$;
revoke all on function public.staff_transition_order(uuid, text, text, boolean) from public, anon;
grant execute on function public.staff_transition_order(uuid, text, text, boolean) to authenticated;
