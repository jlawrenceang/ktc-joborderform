-- ============================================================
-- 0057 — vessel schedule + per-shipping-line free-storage-days
--
-- Models the real KTC vessel schedule (docs/reference/vessel-schedule-sample.jpg):
-- Vessel Name · Voyage Number · Vessel Visit · Actual Date Arrival ·
-- Finish Discharging · Last Free Day of Storage · Berth.
--
-- Design decisions (owner, 2026-06-13):
--   * "Vessel Visit" (e.g. 26RUH02) is the call's natural key — seed of the
--     TOS vessel-call entity (ADR-0015 north star).
--   * "Last Free Day of Storage" is COMPUTED, not entered: finish_discharging +
--     the shipping line's import free-days. It depends on the line, so free-days
--     are a per-line SETTING (import + export).
--   * "Current" is auto-derived from last_free_day >= today (no manual closing).
--     Operations just adds new arrivals; past calls drop off the JO dropdown by
--     themselves. A `cancelled` flag is the only manual override.
-- ============================================================

-- New permission: who maintains the schedule + the free-days setting.
insert into public.role_permissions (role, permission, allowed) values
  ('admin',      'manage_vessel_schedule', true),
  ('operations', 'manage_vessel_schedule', true),
  ('cashier',    'manage_vessel_schedule', false),
  ('checker',    'manage_vessel_schedule', false)
on conflict (role, permission) do nothing;

-- updated_at helper (uniquely named to avoid clobbering anything).
create or replace function public.vessel_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end;
$$;

-- 1) Shipping lines + their free-storage-days (the "setting", per direction).
create table if not exists public.shipping_lines (
  name             text primary key,
  free_days_import int  not null default 5,
  free_days_export int  not null default 7,
  updated_at       timestamptz not null default now()
);
alter table public.shipping_lines enable row level security;

drop policy if exists "read shipping lines" on public.shipping_lines;
create policy "read shipping lines" on public.shipping_lines
  for select to authenticated using (true);

drop policy if exists "manage shipping lines" on public.shipping_lines;
create policy "manage shipping lines" on public.shipping_lines
  for all to authenticated
  using (public.has_permission('manage_vessel_schedule'))
  with check (public.has_permission('manage_vessel_schedule'));

drop trigger if exists shipping_lines_touch on public.shipping_lines;
create trigger shipping_lines_touch before update on public.shipping_lines
  for each row execute function public.vessel_touch_updated_at();

-- 2) Vessel schedule — one row per vessel call, keyed on the visit code.
create table if not exists public.vessel_schedule (
  id                 uuid primary key default gen_random_uuid(),
  vessel_visit       text unique not null,
  vessel_name        text not null,
  voyage_number      text not null,
  shipping_line      text references public.shipping_lines(name) on update cascade,
  actual_arrival     date,
  finish_discharging date,
  berth              text,
  cancelled          boolean not null default false,
  remarks            text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
alter table public.vessel_schedule enable row level security;

drop policy if exists "read vessel schedule" on public.vessel_schedule;
create policy "read vessel schedule" on public.vessel_schedule
  for select to authenticated using (true);

drop policy if exists "manage vessel schedule" on public.vessel_schedule;
create policy "manage vessel schedule" on public.vessel_schedule
  for all to authenticated
  using (public.has_permission('manage_vessel_schedule'))
  with check (public.has_permission('manage_vessel_schedule'));

drop trigger if exists vessel_schedule_touch on public.vessel_schedule;
create trigger vessel_schedule_touch before update on public.vessel_schedule
  for each row execute function public.vessel_touch_updated_at();

create index if not exists vessel_schedule_arrival_idx on public.vessel_schedule (actual_arrival);

-- 3) Read model: last_free_day computed from the line's import free-days, and
--    is_current derived from it. security_invoker so base-table RLS applies.
create or replace view public.vessel_schedule_v
with (security_invoker = true) as
select
  v.*,
  sl.free_days_import,
  sl.free_days_export,
  case
    when v.finish_discharging is not null and sl.free_days_import is not null
    then v.finish_discharging + sl.free_days_import
  end as last_free_day,
  (not v.cancelled and (
     v.finish_discharging is null
     or sl.free_days_import is null
     or (v.finish_discharging + sl.free_days_import) >= current_date
  )) as is_current
from public.vessel_schedule v
left join public.shipping_lines sl on sl.name = v.shipping_line;

grant select on public.vessel_schedule_v to authenticated;
