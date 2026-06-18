-- ============================================================
-- 0118 — close the four "judgment-call" audit items properly (owner, 2026-06-18)
--
-- #1 Staff minting moves off hand-written auth.users onto GoTrue's admin API
--    (edge fn admin-create-staff). This RPC is the second half: owner-gated,
--    sets staff_role/is_admin on the customers row the createUser trigger made.
-- #2 The broad customers self-UPDATE policy gets a POLICY-LAYER privilege guard
--    (defense-in-depth over guard_broker_protected_fields): a non-privileged
--    caller can never self-grant is_admin/is_owner/is_root_owner/staff_role —
--    the UPDATE is denied outright, before the trigger even runs.
-- #3 Reopen 0055's accepted remainder: weave session_alive() into the customer's
--    OWN-profile read/update and OWN storage-folder policies, so an evicted JWT
--    loses access to same-account data immediately (was: usable until ≤1h TTL).
--
-- New caller helpers (client-callable, aal/session aware — NOT internal):
--   current_uid_alive()    -> auth.uid() when the session is alive, else null
--   caller_is_privileged() -> is the caller currently owner/admin/staff
--   is_owner()             -> owner check (session + aal gated), for the edge fn
-- ============================================================

-- ---------- helpers ----------
create or replace function public.current_uid_alive()
returns uuid language sql stable security definer set search_path = public as $$
  select case when public.session_alive() then auth.uid() else null end;
$$;
revoke all on function public.current_uid_alive() from public, anon;
grant execute on function public.current_uid_alive() to authenticated;

-- "Currently privileged" WITHOUT the aal gate — a staff/owner whose session is
-- aal1 must still be able to sync their own profile (the trigger guards changes).
create or replace function public.caller_is_privileged()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_owner or is_admin or staff_role is not null
                   from public.customers where user_id = auth.uid()), false);
$$;
revoke all on function public.caller_is_privileged() from public, anon;
grant execute on function public.caller_is_privileged() to authenticated;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select public.session_alive() and public.aal_satisfied()
         and coalesce((select is_owner from public.customers where user_id = auth.uid()), false);
$$;
revoke all on function public.is_owner() from public, anon;
grant execute on function public.is_owner() to authenticated;

-- ---------- #3 own-profile read: gate on a live session ----------
drop policy if exists "broker reads own profile" on public.customers;
create policy "broker reads own profile" on public.customers
  for select to authenticated using (user_id = public.current_uid_alive());

-- ---------- #2 + #3 own-profile update: live session + privilege guard ----------
drop policy if exists "broker updates own profile" on public.customers;
create policy "broker updates own profile" on public.customers
  for update to authenticated
  using (user_id = public.current_uid_alive())
  with check (
    user_id = public.current_uid_alive()
    and (
      -- owner/admin/staff: guard_broker_protected_fields governs their changes
      public.caller_is_privileged()
      -- plain customers may NEVER self-grant a privilege (hard policy-layer deny)
      or (coalesce(is_admin, false) = false
          and coalesce(is_owner, false) = false
          and coalesce(is_root_owner, false) = false
          and staff_role is null)
    )
  );

-- ---------- #3 own storage folders: gate on a live session ----------
-- valid-ids (0002)
drop policy if exists "user uploads own valid id" on storage.objects;
create policy "user uploads own valid id" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'valid-ids' and (storage.foldername(name))[1] = public.current_uid_alive()::text);
drop policy if exists "user reads own valid id" on storage.objects;
create policy "user reads own valid id" on storage.objects
  for select to authenticated
  using (bucket_id = 'valid-ids' and (storage.foldername(name))[1] = public.current_uid_alive()::text);

-- payment-slips (0036)
drop policy if exists "user uploads own payment slip" on storage.objects;
create policy "user uploads own payment slip" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'payment-slips' and (storage.foldername(name))[1] = public.current_uid_alive()::text);
drop policy if exists "user updates own payment slip" on storage.objects;
create policy "user updates own payment slip" on storage.objects
  for update to authenticated
  using (bucket_id = 'payment-slips' and (storage.foldername(name))[1] = public.current_uid_alive()::text);
drop policy if exists "user reads own payment slip" on storage.objects;
create policy "user reads own payment slip" on storage.objects
  for select to authenticated
  using (bucket_id = 'payment-slips' and (storage.foldername(name))[1] = public.current_uid_alive()::text);

-- jo-documents (0069)
drop policy if exists "user uploads own jo document" on storage.objects;
create policy "user uploads own jo document" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'jo-documents' and (storage.foldername(name))[1] = public.current_uid_alive()::text);
drop policy if exists "user reads own jo document" on storage.objects;
create policy "user reads own jo document" on storage.objects
  for select to authenticated
  using (bucket_id = 'jo-documents' and (storage.foldername(name))[1] = public.current_uid_alive()::text);

-- ---------- #1 staff promotion RPC (auth.users now made via GoTrue admin API) ----------
create or replace function public.promote_new_staff(p_user_id uuid, p_role text, p_full_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not coalesce((select is_owner from public.customers where user_id = auth.uid()), false) then
    raise exception 'Only the owner can create staff';
  end if;
  if p_role not in ('admin','cashier','checker','operations','csr') then
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
end;
$$;
revoke all on function public.promote_new_staff(uuid, text, text) from public, anon;
grant execute on function public.promote_new_staff(uuid, text, text) to authenticated;
