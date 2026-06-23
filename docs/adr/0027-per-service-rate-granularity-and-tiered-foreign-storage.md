# ADR-0027: Per-service rate granularity + a tiered foreign storage tariff for the calculator

* Status: Accepted
* Deciders: Owner (Jan Lawrence Ang)
* Date: 2026-06-23
* Category: Business Logic | Database

## Context and Problem Statement

The rate calculator's tariff (`terminal_rates`, migration `0141`) is a fixed six-dimension matrix — service × trade × origin × size × fill × kind = 160 cells — all hand-filled. In practice most services don't vary across all six dimensions (LoLo is flat; weighing/wharfage vary by size; only arrastre uses origin × size × fill), so the matrix forced the owner to type the same number into dozens of cells. Separately, foreign **storage** is not a single per-day rate at all: it is a *progressive tiered* per-day tariff whose day-bands and rates differ per trade direction (Import / Export / Transhipment) × size, while domestic storage is a flat per-day rate by size. A flat per-cell value cannot represent day-bands. How should the calculator model per-service rate granularity and the tiered storage tariff — without disturbing live billing or the calculator's lookup?

## Decision Drivers

* Match reality — each service should configure only the conditions its rate actually depends on (uniform, or any subset of origin/size/fill/kind).
* Storage is genuinely tiered for foreign cargo — the estimate must compute a **cumulative** tiered total, not a flat rate × days.
* Don't disturb live billing — `service_rates` remains the live payment tariff; `terminal_rates`/this model is **calculator (quote) only**.
* Don't rewrite the calculator's lookup — keep the existing keyed read working.
* Admin-configurable + no-zero — the owner sets dimensions and rates in Settings; unset rates render "not set", never ₱0.

## Considered Options

* **A — Per-service granularity config + a dedicated storage-tier table.** `terminal_rate_config(service, dims[])` declares which dimensions each service varies by; the Settings editor shows only those inputs and *fans the value out* to the physical `terminal_rates` cells, so the calculator's six-key lookup is unchanged. Storage gets its own `storage_tiers` table + cumulative tiered math (foreign); domestic storage stays flat by size in `terminal_rates`.
* **B — Collapse the matrix globally** (drop the dimensions that no service uses).
* **C — A UX bulk-fill helper only** ("set one rate for all configs").
* **D — Encode storage tiers inside `terminal_rates`** with sentinel/extra columns.

## Decision Outcome

Chosen option: **A** (migration `0157`), because it is the only option that fixes *both* problems while leaving the calculator lookup and live billing untouched. Per-service granularity is fan-out over the existing matrix (so reads don't change); the genuinely different shape of storage gets its own table + cumulative computation. Storage tiering is **cumulative** (chargeable days walk the bands in sequence, escalating), charging starts **after the line's free days**, domestic is **flat per-day by size**, and **empties use the laden rates**; **Transhipment** was added as a foreign-only trade option.

### Positive Consequences

* The owner configures only the dimensions that matter per service; far less repetitive data entry.
* Foreign storage is modeled and computed correctly (cumulative tiered); domestic stays simple.
* The calculator's keyed lookup is unchanged — fan-out keeps the physical cells consistent.
* Live billing (`service_rates`) is untouched; the whole change is reversible/config-driven.

### Negative Consequences / Trade-offs

* `terminal_rates` stays **denormalized** — fan-out writes the same value across the irrelevant dimensions (invisible to users, but present in the table).
* Storage runs a **separate model + editor** from the other services (two code paths).
* The per-service dimensions are **seeded from observed data** (arrastre = origin×size×fill, weighing/wharfage = size, LoLo = uniform) and may need owner adjustment.
* Storage tiering anchors band 1 to the line's free-day count, so the sheet's absolute day numbers act as band *widths/rates* rather than fixed calendar days.

## Pros and Cons of Options

### A — Per-service config + storage-tier table (fan-out)

* Good, because reads (the calculator) are unchanged and live billing is untouched.
* Good, because storage gets a model that actually fits its tiered shape.
* Bad, because the matrix stays denormalized and storage is a second code path.

### B — Collapse the matrix globally

* Good, because the table shrinks.
* Bad, because different services need different dimensions — a global collapse loses arrastre's granularity.

### C — Bulk-fill helper only

* Good, because lowest effort, no schema change.
* Bad, because it doesn't address tiered storage at all (the harder half).

### D — Storage tiers inside `terminal_rates`

* Good, because one table.
* Bad, because day-bands don't fit the fixed six-key schema; sentinels break the unique key and the lookup.

## Related ADRs

* Extends the `0141` container rate matrix (migration-only; no prior ADR) and the calculator/quote tariff model.
* Distinct from live billing — see the `service_rates` / payment-computation path (ADR-0014, ADR-0021); this model is quote-only.

## References

* Migration `0157` (`supabase/migrations/0157_storage_tiers_and_rate_granularity.sql`).
* `src/lib/release.ts` is unrelated; relevant code: `src/pages/Calculator.tsx` (tiered storage math), `src/admin/Settings.tsx` (dim-toggle + storage editor).
