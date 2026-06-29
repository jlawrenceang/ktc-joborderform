-- ============================================================
-- 0198 — Harden the owner crown-jewel RPCs (security audit #2 A1 + #2 C-logging)
--
-- The highest-value owner operations gated on the RAW is_owner column:
--   coalesce((select is_owner from customers where user_id = auth.uid()), false)
-- which skips the MFA (aal2) + live-session hardening that protects the rest of
-- the system. So a phished owner PASSWORD (an aal1 session) could still mint staff,
-- reset staff passwords, or grant owner — bypassing exactly the controls built to
-- contain owner-password compromise.
--
-- Fix: gate on public.is_owner() instead (0184) — it ANDs session_alive() +
-- aal_satisfied() AND keeps the jlawrenceang@gmail.com email failsafe, so:
--   * an aal1 (password-only) session can't perform these once MFA is enrolled,
--   * a non-MFA owner still works (aal_satisfied() = true with no factor),
--   * the email failsafe inside is_owner() means the owner can NEVER be locked out.
-- is_root_owner() likewise gains session_alive() + aal_satisfied().
-- Recreated verbatim from 0115 / 0150 / 0093 with ONLY the gate swapped (+ a
-- staff-mint security-event log for the #2 C out-of-band detection).
-- ============================================================

-- reset_staff_password — was 0115
create or replace function public.reset_staff_password(p_username text, p_password text)
returns void language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  v_email text := lower(trim(p_username)) || '@ktc-staff.local';
begin
  if not public.is_owner() then
    raise exception 'Only the owner can reset staff passwords';
  end if;
  if length(coalesce(p_password, '')) < 8
     or p_password !~ '[A-Za-z]' or p_password !~ '[0-9]' then
    raise exception 'Password must be at least 8 characters and include a letter and a number';
  end if;
  update auth.users
  set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now()
  where email = v_email;
  if not found then raise exception 'No staff account "%"', lower(trim(p_username)); end if;

  perform public.log_security_event(
    'staff_password_reset',
    (select id from public.customers where email = v_email),
    jsonb_build_object('username', lower(trim(p_username)))
  );
end;
$$;
revoke all on function public.reset_staff_password(text, text) from public, anon;
grant execute on function public.reset_staff_password(text, text) to authenticated;

-- promote_new_staff — was 0150; + log every mint (audit #2 C detection)
create or replace function public.promote_new_staff(p_user_id uuid, p_role text, p_full_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then
    raise exception 'Only the owner can create staff';
  end if;
  if p_role not in ('admin','cashier','checker','operations','csr','purchaser') then
    raise exception 'Unknown role %', p_role;
  end if;
  update public.customers
  set is_admin   = (p_role = 'admin'),
      staff_role = p_role,
      status     = 'approved',
      full_name  = p_full_name,
      decided_at = now()
  where user_id = p_user_id;
  if not found then raise exception 'No account row for the new staff user.'; end if;

  -- audit #2 C: log every staff mint so it surfaces in the security log + the
  -- owner out-of-band alert (a silent rogue mint becomes visible).
  perform public.log_security_event(
    'staff_promoted',
    (select id from public.customers where user_id = p_user_id),
    jsonb_build_object('role', p_role, 'full_name', p_full_name)
  );
end;
$$;
revoke all on function public.promote_new_staff(uuid, text, text) from public, anon;
grant execute on function public.promote_new_staff(uuid, text, text) to authenticated;

-- is_root_owner — was 0093; gains the MFA + live-session guarantee (gates set_owner_access)
create or replace function public.is_root_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select public.session_alive() and public.aal_satisfied()
     and coalesce((select is_root_owner from public.customers where user_id = auth.uid()), false);
$$;
