---
title: Pending Items
tags: [memory, pending, backlog]
type: memory
last_updated: 2026-06-13
---

# 📋 Pending Items

Detailed backlog. For sequencing, see [[Roadmap]]. (Pre-v1.1.0 completed items moved to [[Completed Milestones]] / `CHANGELOG.md`.)

## ST02 / trial run (NOW)

- [ ] **ST02 manual Lanes 1–8** on `portal.ktcterminal.com` (`docs/smoke-test-02-portal.md`). Preflight P1–P8 ✅ (P8 cleared 2026-06-13 after E2E key regen → Playwright 16/16). Owner walking lanes now.
- [ ] **P9 / Lane 5.0 data entry:** real X-Ray rate + admin/print fees, bank/GCash details + QR upload (Settings, owner).
- [ ] **ST02 teardown:** suspend/remove test accounts + orders, reset `jo_number_seq` / `broker_code_seq` (only safe at zero orders) so the first real order is `JO-000001`.

## Go-live gate (NEXT)

- [ ] **Counsel sign-off on Customer Agreement v2** — DPO designation, NPC registration check, liability cap amount. Bump `AGREEMENT_VERSION` on material change.
- [ ] Enforce re-acceptance when `AGREEMENT_VERSION` changes for already-registered customers.
- [ ] Public-launch call (remove the prod-testing restriction).

## JO modernization + port-services billing (from real KTC forms, 2026-06-13)

*Grounded in `docs/reference/` (X-ray JO, RPS, Service Invoice samples). Owner decisions captured there.*

- [ ] **New staff role: `operations`** (the ops floor — was anticipated as the "employee role distinct from admin"). Maintains the **vessel schedule** and acts as **assessor** (assess RPS need → upload + moves entry); files/processes JOs. Roles are data-driven (`role_permissions` matrix + `has_permission`), so this is: a migration to extend the `customers_staff_role_check` constraint (`admin`/`cashier`/`checker` → + `operations`) + matrix rows + Settings role dropdown + role badge/landing + operations manual/tour. Proposed scope: view/file/process JOs, manage consignees + vessel schedule, **assess_rps** — **no** payments/invoice/approvals/customers/pricing/settings/security. New permissions to add with the features: `manage_vessel_schedule`, `assess_rps`. *(Open: is "assessor" folded into operations, or its own role for separation of duties?)*
- [ ] **Vessel schedule + JO vessel/voyage dropdown.** New `vessel_schedule` table modeled on the real KTC schedule (`docs/reference/vessel-schedule-sample.jpg`): **vessel_name, voyage_number, vessel_visit** (call code e.g. `26RUH02` — natural key + seed of the TOS vessel-call entity), **actual_arrival, finish_discharging, last_free_day** (the storage/demurrage clock), **berth**, + status & remarks. Admin CRUD (RLS read=auth / write=`manage_vessel_schedule`); JO form replaces free-text with a picker of **current** vessel/voyage. **Anti-bottleneck:** derive "current" from dates (`last_free_day >= today`) so ops don't manually close every vessel, **+ a "vessel not listed → request it" escape hatch** so a missing entry never blocks filing. First concrete step toward the TOS vessel module ([[Terminal & Depot Operating System (North Star)]]; supersedes the old [[Vessel Schedule Monitoring]] idea). *(No packages/cargo-nature/gross-weight — owner dropped those.)*
- [ ] **RPS = assessment-driven per-move billing (not customer-selected).** Model (owner 2026-06-13): **every JO queues immediately** (serving number, base charge known) → an **assessor** (operations) assesses *does it need RPS?* → if yes, upload the RPS (reuse valid-ID/payment-proof upload+review) + enter **moves per move-type** → per-move charges (VATable) **added** to the base → final total = base + RPS. New `move_rates` config (move-type + rate, like `service_rates`), seeded from the Service Invoice (Shifting ₱950.86, Trucking ₱1,000, Lift On ₱730.83, + Stripping/Stuffing TBD). Needs an assessment state (`rps_status`: not-assessed / not-needed / needed) + assessor UI; feeds the charge/payment computation. **Open: payment timing** — (i) pay base now, RPS added/settled later *(recommended, since RPS is rare)*, or (ii) finalize total after assessment, pay once.
- [ ] Combined **X-Ray + DEA** = ₱2,918 (X-Ray flat) + RPS per-move total at review — *confirm with owner.*

## Payments / pricing open decisions

- [ ] **Invoice generation trigger** — when is the cashier's Service Invoice produced (on `completed`? "ready for payment"? on demand)? Invoice lives in the **ERP**; app records `OR-INV-`/`BI-INV-` + pad no. as PAID/BILLED.
- [ ] **Payment ↔ cashier handoff** — does an admin-confirmed online payment proof replace the cashier visit for the official BIR invoice/OR, or still require it?

## Integrations / automation

- [ ] **BOC Sheets mirror** — blocked on Google service-account creds (`scripts/setup-boc-mirror.mjs`). One-way app→Sheet only (no two-way sync — bypasses RLS/caps/guards).
- [ ] **Bounded admin import** (staff template sheet → validated RPC upsert) if staff data-entry need materializes; decide fields/who/cadence. Prefer import-to-staging + admin confirm.
- [ ] **Regenerate a real `sbp_` personal access token** — `SUPABASE_ACCESS_TOKEN` in `.env.local` is a secret API key; the 4 Management-API scripts fail until then (see `docs/agent/tooling-inventory.md`).

## Deferred features

- [ ] JO operational fields: container size, vessel/voyage, plug-in/out timestamps (deferred 2026-06-11).
- [ ] Per-customer accredited-consignee scoping (ADR-0007 keeps the open master list; revisit on chokepoints).
- [ ] JO draft persistence; document attachments on orders.
- [ ] Status-change notification emails beyond the current set (decide after lifecycle finalization).
- [ ] Possible **employee role** distinct from admin for in-house filing division.

## Testing / CI (LATER)

- [ ] Implement the 4 Playwright mutation `fixme` lanes (registration→approval, consignee CRUD, JO submit, staff creation).
- [ ] Wire Playwright into CI (GitHub Actions) once a workflow exists.
- [ ] Process the 2,488 imported consignees through accreditation over time.

## Ops notes

- Turnstile secret lives only in Supabase; site key in Vercel env (`VITE_TURNSTILE_SITE_KEY`). Env changes need a redeploy.
- Session pooler (`:5432`) can exhaust mid-session → use transaction pooler (`:6543`) for one-off scripts.
- ID purge cron is ACTIVE (Vault has `service_role_key` + `project_url`; verified 2026-06-13). All 6 crons green.

## Related

- [[Roadmap]] · [[Current State]] · [[Home]]
