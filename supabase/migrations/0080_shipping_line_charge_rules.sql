-- ============================================================
-- 0080 — per-shipping-line charge rules (owner, 2026-06-16)
--
-- Generalises the hardcoded "Maersk/MCC waive LoLo on export" into admin-managed
-- DATA. Each rule layers on top of the base terminal_rates tariff (0073/0078):
-- per line × charge × trade, KTC can WAIVE a charge, DISCOUNT it (% or ₱/container),
-- or add a SURCHARGE (₱/container). Free storage days stay per-line on
-- shipping_lines (free_days_import/export) — this table is only money rules.
--
-- shipping_line stores the line CODE (MAERSK, MCC, EVERGREEN, SITC, MSC, CMA-CGM)
-- to match the Rate Calculator. trade = null means the rule applies to both
-- import and export. The calculator reads active rules and applies them.
-- ============================================================

create table if not exists public.shipping_line_charge_rules (
  id            uuid primary key default gen_random_uuid(),
  shipping_line text not null,
  service       text not null check (service in ('arrastre', 'wharfage', 'lolo', 'weighing', 'storage')),
  trade         text check (trade in ('import', 'export')),     -- null = both
  action        text not null check (action in ('waive', 'discount_pct', 'discount_amt', 'surcharge_amt')),
  value         numeric not null default 0,                     -- % or ₱/container; ignored for 'waive'
  note          text,
  active        boolean not null default true,
  updated_at    timestamptz not null default now()
);

alter table public.shipping_line_charge_rules enable row level security;

drop policy if exists "read line charge rules" on public.shipping_line_charge_rules;
create policy "read line charge rules" on public.shipping_line_charge_rules
  for select to authenticated using (true);

drop policy if exists "manage line charge rules" on public.shipping_line_charge_rules;
create policy "manage line charge rules" on public.shipping_line_charge_rules
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Seed the existing rule as data: Maersk & MCC shoulder the customer's LoLo on
-- export, so it's waived for them.
insert into public.shipping_line_charge_rules (shipping_line, service, trade, action, value, note)
select c, 'lolo', 'export', 'waive', 0, 'Line shoulders the customer''s LoLo on export'
from unnest(array['MAERSK', 'MCC']) c
on conflict do nothing;
