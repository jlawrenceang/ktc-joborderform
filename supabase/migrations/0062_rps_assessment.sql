-- ============================================================
-- 0062 — RPS assessment + per-move billing
--
-- Model (owner, 2026-06-13): every JO queues immediately with its base charge.
-- Operations (assessor) confirms whether it needs RPS (port-services moves for
-- DEA/inspection). If so they upload the RPS and enter the number of moves per
-- type; each move type bills at an admin-set, VATable per-move rate, added on
-- top of the base. Most JOs need none.
-- ============================================================

-- 1) Per-move rates — admin-configured (manage_pricing), like service_rates.
create table if not exists public.move_rates (
  move_type  text primary key,
  rate       numeric(12,2) not null default 0,
  active     boolean not null default true,
  sort_order int,
  updated_at timestamptz not null default now()
);
alter table public.move_rates enable row level security;

drop policy if exists "read move rates" on public.move_rates;
create policy "read move rates" on public.move_rates
  for select to authenticated using (true);

drop policy if exists "manage move rates" on public.move_rates;
create policy "manage move rates" on public.move_rates
  for all to authenticated
  using (public.has_permission('manage_pricing'))
  with check (public.has_permission('manage_pricing'));

-- Seed from the sample Service Invoice (admin tunes; Stripping/Stuffing = 0 placeholder).
insert into public.move_rates (move_type, rate, sort_order) values
  ('Shifting', 950.86, 1),
  ('Trucking', 1000.00, 2),
  ('Lift On',  730.83, 3),
  ('Stripping', 0, 4),
  ('Stuffing',  0, 5)
on conflict (move_type) do nothing;

-- 2) Assessor permission (operations + admin).
insert into public.role_permissions (role, permission, allowed) values
  ('admin',      'assess_rps', true),
  ('operations', 'assess_rps', true),
  ('cashier',    'assess_rps', false),
  ('checker',    'assess_rps', false)
on conflict (role, permission) do nothing;

-- 3) Assessment state on the JO.
alter table public.job_orders add column if not exists rps_status text not null default 'not_assessed'
  check (rps_status in ('not_assessed', 'not_needed', 'needed'));
alter table public.job_orders add column if not exists rps_path text;
alter table public.job_orders add column if not exists rps_assessed_at timestamptz;
alter table public.job_orders add column if not exists rps_assessed_by uuid;

-- 4) Moves per JO (one row per move type).
create table if not exists public.rps_moves (
  id           uuid primary key default gen_random_uuid(),
  job_order_id uuid not null references public.job_orders(id) on delete cascade,
  move_type    text not null,
  qty          integer not null default 0,
  unique (job_order_id, move_type)
);
alter table public.rps_moves enable row level security;

-- Read: the owning customer (for their pay page breakdown) + any staff who can
-- view job orders. Writes go only through the RPC below.
drop policy if exists "read rps moves" on public.rps_moves;
create policy "read rps moves" on public.rps_moves
  for select to authenticated using (
    exists (select 1 from public.job_orders jo where jo.id = job_order_id
            and (jo.customer_id = public.current_broker_id() or public.has_permission('view_job_orders')))
  );

-- 5) Record an assessment (gated on assess_rps) — sets status, doc + moves.
create or replace function public.record_rps_assessment(p_jo uuid, p_needed boolean, p_path text, p_moves jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.has_permission('assess_rps') then
    raise exception 'You don''t have permission to assess RPS.';
  end if;
  update public.job_orders
     set rps_status = case when p_needed then 'needed' else 'not_needed' end,
         rps_path = p_path,
         rps_assessed_at = now(),
         rps_assessed_by = auth.uid()
   where id = p_jo;
  if not found then raise exception 'Job order not found.'; end if;
  delete from public.rps_moves where job_order_id = p_jo;
  if p_needed and p_moves is not null then
    insert into public.rps_moves (job_order_id, move_type, qty)
    select p_jo, key, value::int from jsonb_each_text(p_moves) where coalesce(value, '0')::int > 0;
  end if;
end;
$$;
revoke all on function public.record_rps_assessment(uuid, boolean, text, jsonb) from public, anon;
grant execute on function public.record_rps_assessment(uuid, boolean, text, jsonb) to authenticated;

-- 6) RPS document bucket — assessor uploads, staff read (internal doc).
insert into storage.buckets (id, name, public) values ('rps-docs', 'rps-docs', false)
on conflict (id) do nothing;

drop policy if exists "rps upload" on storage.objects;
create policy "rps upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'rps-docs' and public.has_permission('assess_rps'));

drop policy if exists "rps update" on storage.objects;
create policy "rps update" on storage.objects
  for update to authenticated
  using (bucket_id = 'rps-docs' and public.has_permission('assess_rps'));

drop policy if exists "rps read staff" on storage.objects;
create policy "rps read staff" on storage.objects
  for select to authenticated
  using (bucket_id = 'rps-docs' and public.has_permission('view_job_orders'));
