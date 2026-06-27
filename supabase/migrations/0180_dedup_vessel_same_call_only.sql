-- 0180: fix dedup_vessel_schedule so it only collapses the SAME physical call (a
-- date→week key flip), not two genuinely distinct calls of the same vessel+voyage.
-- 0158's trigger matched on (vessel_name, voyage_number) alone and deleted any row with
-- a different vessel_visit — but deriveVisit deliberately keeps distinct weekly calls of
-- the same vessel+voyage as separate rows (week/arrival discriminator), so a second
-- legitimate call silently destroyed the first (data loss, no warning). Narrowing the
-- match by actual_arrival (the call's physical date) keeps the key-flip de-dup working
-- while preserving distinct calls. (Past over-collapse from 0158's one-time DELETE can't
-- be recovered here — a fresh Sheet sync re-creates any wrongly-removed call.)
create or replace function public.dedup_vessel_schedule()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.vessel_schedule
   where vessel_name = new.vessel_name
     and voyage_number = new.voyage_number
     and actual_arrival is not distinct from new.actual_arrival   -- same physical call only
     and vessel_visit is distinct from new.vessel_visit;
  return new;
end;
$$;
revoke all on function public.dedup_vessel_schedule() from public, authenticated, anon;
