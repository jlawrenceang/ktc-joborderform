-- ============================================================
-- 0128 — rate/fee placeholders are EMPTY (NULL), never 0 (owner 2026-06-21)
--
-- "No zero" pass (part 2). A seeded 0 rate is indistinguishable from a real
-- ₱0 and (per owner) can't be cleared — so unset rates/fees become NULL and the
-- UI shows "not set" instead of ₱0.00. All charge computation is FRONTEND
-- (src/lib/pricing.ts + Calculator/Payment), which now treats NULL or ≤0 as
-- "not configured" — so this migration is backend-safe and ships with that code.
--
-- vat_rate (0.12) is a real value and is preserved. shipping_line_charge_rules
-- and rps_moves.qty intentionally untouched (0 is valid there).
-- ============================================================

-- Make the placeholder rate/fee columns nullable, no default.
alter table public.service_rates    alter column rate  drop not null, alter column rate  drop default;
alter table public.move_rates       alter column rate  drop not null, alter column rate  drop default;
alter table public.terminal_rates   alter column rate  drop not null, alter column rate  drop default;
alter table public.pricing_settings alter column value drop not null, alter column value drop default;

-- Null-out the seeded placeholder zeros (keep real values like vat_rate).
update public.service_rates    set rate  = null where rate  = 0;
update public.move_rates       set rate  = null where rate  = 0;
update public.terminal_rates   set rate  = null where rate  = 0;
-- Null every 0-valued setting EXCEPT vat_rate (catches admin_fee, print_fee,
-- reefer_rate, and any other placeholder fee/rate). reefer_min_hours (4) /
-- reefer_deposit (10000) aren't 0, so they're unaffected.
update public.pricing_settings set value = null where key <> 'vat_rate' and value = 0;
