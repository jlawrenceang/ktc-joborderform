-- 0158: De-duplicate vessel_schedule + prevent recurrence.
-- The vessel-sync derives vessel_visit as "<name> <voyage> <disc>" where disc is
-- the sheet's week ("W26") if present, ELSE the arrival date. When ops fill in the
-- week column for a row that was first synced without it, the key flips
-- (…2026-06-21 → …W26) and a SECOND row is inserted for the same visit — the source
-- of the duplicate vessel entries. Fix: collapse existing dupes, then enforce
-- one-row-per-(vessel_name, voyage_number) on every insert/update regardless of the
-- key format.

-- 1) Collapse existing duplicates — keep the most-recently-updated row per visit.
delete from public.vessel_schedule a
using public.vessel_schedule b
where a.vessel_name = b.vessel_name
  and a.voyage_number = b.voyage_number
  and a.vessel_visit <> b.vessel_visit
  and (a.updated_at < b.updated_at
       or (a.updated_at = b.updated_at and a.created_at < b.created_at)
       or (a.updated_at = b.updated_at and a.created_at = b.created_at and a.vessel_visit < b.vessel_visit));

-- 2) Trigger: when a row is inserted/updated, drop any other row for the same
-- vessel+voyage carrying a different (stale-format) vessel_visit key.
create or replace function public.dedup_vessel_schedule()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.vessel_schedule
   where vessel_name = new.vessel_name
     and voyage_number = new.voyage_number
     and vessel_visit is distinct from new.vessel_visit;
  return new;
end;
$$;
-- Trigger-only definer fn — never call it directly (definer-ACL invariant).
revoke all on function public.dedup_vessel_schedule() from public, authenticated, anon;

drop trigger if exists vessel_schedule_dedup on public.vessel_schedule;
create trigger vessel_schedule_dedup
  after insert or update on public.vessel_schedule
  for each row execute function public.dedup_vessel_schedule();
