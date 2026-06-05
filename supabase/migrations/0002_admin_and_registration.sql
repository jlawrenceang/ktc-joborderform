-- ============================================================
-- 0002 — registration profile fields, valid-ID storage, admin framework
-- Run in the KTC Supabase project SQL Editor after 0001.
-- ============================================================

-- ---------- broker profile fields (full name + uploaded ID) ----------
alter table public.brokers add column if not exists full_name     text;
alter table public.brokers add column if not exists valid_id_path text;

-- capture full_name from signup metadata into the auto-created profile
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.brokers (user_id, email, full_name)
  values (new.id, new.email, nullif(new.raw_user_meta_data->>'full_name',''))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

-- ---------- admin helper (SECURITY DEFINER so it bypasses RLS = no recursion) ----------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.brokers where user_id = auth.uid()), false)
$$;

-- ---------- admin RLS: read all brokers; read + decide all accreditations ----------
drop policy if exists "admin reads all brokers" on public.brokers;
create policy "admin reads all brokers" on public.brokers
  for select to authenticated using (public.is_admin());

drop policy if exists "admin reads all accreditations" on public.accreditations;
create policy "admin reads all accreditations" on public.accreditations
  for select to authenticated using (public.is_admin());

drop policy if exists "admin updates accreditations" on public.accreditations;
create policy "admin updates accreditations" on public.accreditations
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- valid-ID storage bucket (private) ----------
insert into storage.buckets (id, name, public)
values ('valid-ids', 'valid-ids', false)
on conflict (id) do nothing;

-- a user manages only their own folder (<user_id>/...); admins may read all
drop policy if exists "user uploads own valid id" on storage.objects;
create policy "user uploads own valid id" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'valid-ids' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "user reads own valid id" on storage.objects;
create policy "user reads own valid id" on storage.objects
  for select to authenticated
  using (bucket_id = 'valid-ids' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "admin reads all valid ids" on storage.objects;
create policy "admin reads all valid ids" on storage.objects
  for select to authenticated
  using (bucket_id = 'valid-ids' and public.is_admin());
