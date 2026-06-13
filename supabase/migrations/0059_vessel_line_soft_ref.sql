-- ============================================================
-- 0059 — vessel_schedule.shipping_line is a soft (text) reference
--
-- Drops the FK to shipping_lines so the bulk importer never fails on a line
-- that admin hasn't configured yet. The line is just a label on the call; the
-- read view left-joins shipping_lines by name for free-days (null-safe until
-- admin adds the line + free-days in Settings — keeps line/free-days admin-only,
-- owner decision A1). Operations record the vessel + line name; admin curates
-- the line master separately.
-- ============================================================

alter table public.vessel_schedule
  drop constraint if exists vessel_schedule_shipping_line_fkey;
