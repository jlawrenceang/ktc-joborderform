-- ============================================================
-- 0052 — valid-ID minimum retention window (decision 2026-06-12).
--
-- Policy change: uploaded IDs are NO LONGER deleted instantly on approval.
-- They are kept for a MINIMUM of 7 days from upload (verification + dispute
-- window), after which an admin may delete them from the file viewer
-- (🗑 Delete). Enforced server-side, not just in the UI: the storage DELETE
-- policy only permits removal once the window has passed.
--
--   * customers.valid_id_uploaded_at — stamped by trigger whenever
--     valid_id_path is set/replaced; cleared with it.
--   * storage policy "admin deletes valid ids" gains the 7-day condition
--     (files with no tracked upload time — legacy — stay deletable).
-- ============================================================

alter table public.customers add column if not exists valid_id_uploaded_at timestamptz;

create or replace function public.stamp_valid_id_uploaded()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.valid_id_path is distinct from old.valid_id_path then
    new.valid_id_uploaded_at := case when new.valid_id_path is null then null else now() end;
  end if;
  return new;
end;
$$;
drop trigger if exists customers_stamp_valid_id on public.customers;
create trigger customers_stamp_valid_id before update of valid_id_path on public.customers
  for each row execute function public.stamp_valid_id_uploaded();

-- Backfill: anything currently on file has no tracked age — treat as past the
-- window (deletable) by leaving valid_id_uploaded_at null.

drop policy if exists "admin deletes valid ids" on storage.objects;
create policy "admin deletes valid ids" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'valid-ids'
    and public.is_admin()
    -- minimum 7-day retention from upload; unknown age (legacy) and orphaned
    -- files (account deleted) are deletable immediately
    and not exists (
      select 1 from public.customers c
      where c.user_id::text = (storage.foldername(name))[1]
        and c.valid_id_uploaded_at >= now() - interval '7 days'
    )
  );
