---
title: Job Order Lifecycle
tags: [workflow, job-orders, lifecycle]
type: workflow
status: draft-for-finalization
last_updated: 2026-06-11
---

# 🔄 Job Order Lifecycle (source of truth)

> Status legend: ✅ built · 🔸 decided, not yet built · ❓ open decision.
> This is the agreed end-to-end flow to finalize **before** committing to the final build cycle (#10).

## Actors

- **Customer** (customs broker) — files JOs against consignees.
- **Admin / staff** — process JOs, file in-house JOs, configure rates, review payments. `is_admin()` (incl. Owner).
- **Owner** — superset of admin; server-only failsafe.
- ❓ **Employee role** (future) — distinct from admin (currently staff = `is_admin`).
- **KTC ERP** (external, not linked yet) — produces the official **Service Invoice + BIR receipt**.

## A. Account lifecycle (prerequisite) ✅

`register` (name + contact + email + password + consent + CAPTCHA) → `confirm email` → sign in **`pending`** → upload valid ID at `/verify-id` → admin **approve** (releases held orders, deletes ID) / **reject** (recoverable: resubmit) / **suspend** (terminal). 48h TTL auto-rejects no-ID pendings. *(ADR-0012, ADR-0013.)*

## B. Job Order states

| State | Meaning | Notes |
|---|---|---|
| `held` ✅ | Filed by a **pending** (unverified) customer | Queue-hidden; ≤10; **no JO number yet** ("Draft") |
| `submitted` ✅ | Live in the admin queue | JO number assigned; **enters the service serving-line** |
| `processing` ✅ | Admin **approved** & working it | =approved; printable slip; "ON PROCESS" watermark |
| `on_hold` ✅ | Admin needs info | Customer-visible `admin_note`; ❓ customer response path |
| `completed` ✅ | Done | Clean printable slip |
| `rejected` ✅ | Admin declined | Customer-visible `admin_note`; 🔸 resubmit/refile |
| `cancelled` ✅ | Customer-cancelled or auto on account suspend/reject | 🔸 customer cancel UI to build |

## C. Transitions (who triggers)

- **File** (customer) → `held` (if pending) or `submitted` (if approved). ✅
- **File on behalf** (admin/employee, in-house ops) → `submitted`. ✅ (`0041`, `/admin/new-job-order`, `file_job_orders` gate; staff filings bypass the order caps.)
- **Account approved** (admin) → all that customer's `held` → `submitted` (release trigger). ✅
- **Approve & process** (admin) → `submitted` / `on_hold` → `processing`. ✅
- **Mark completed** (admin) → `processing` → `completed`. ✅
- **Hold for info** (admin, +note) → `submitted` / `processing` → `on_hold`. ✅
- **Reject** (admin, +note) → `submitted` / `processing` / `on_hold` → `rejected`. ✅ Admin picks **recoverable** (default) vs **terminal** at reject time (`rejected_recoverable`, migration `0034`).
- **Resubmit after reject** (customer) → `rejected` → `submitted`. ✅ (`resubmit_rejected` RPC; only when recoverable; re-checks the open-order cap; optional customer note.)
- **Respond to hold** (customer) → `on_hold` → `submitted`. ✅ (`respond_to_hold` RPC; required reply note shown to admin as **Customer reply**; can correct the entry number.)
- **Edit** (customer) → content change, state unchanged. 🔸 deferred — only the entry-number fix inside respond-to-hold exists; full edit ties to serving numbers (#8).
- **Cancel** (customer) → `held` / `submitted` / `on_hold` → `cancelled`. ✅ (`cancel_job_order` RPC + confirm UI; not once `processing` — contact admin.)

## D. Numbering & priority

- **JO number `JO-######`** ✅ — **permanent identity**; assigned by `ensure_jo_number` on first live status; global, atomic, never reused; gaps are fine.
- **Service serving number** ✅ BUILT (migration `0038`, `serving_numbers` table) — "now serving" per service line (`xray`/`dea`/`oog`), **separate** from the JO number.
  - Grain: **per JO, per service line**. Reset: **weekly** (Monday, Asia/Manila). Assigned on `submitted` (triggers on status + line insert; numbers only written by SECURITY DEFINER functions).
  - **Respond-to-hold** → keeps its number ✅. **Customer EDIT of a FILED (`submitted`) order** → **back of the line** (vacate + reassign) so KTC re-reviews it (`0079`, owner 2026-06-16 — **reverses** the earlier "edit keeps its number"; a `held` draft has no number yet, so nothing to requeue). **Cancel / reject** → vacated (burned, unique index keeps it unreusable) ✅. **Resubmit after reject** → back of line; admin **"↩ Restore #N"** button on the queue (`restore_serving_number`, same week only) ✅.
  - Surfaces: **Now-Serving board** (`now_serving()` RPC — My Job Orders + Checker), serving chips on customer/admin cards, checker queue **sorted by line number**, and the number printed on the **A6 slip**.
  - ❓ Carry-over policy at the weekly reset still open — see [[Process Flow Map]] G2.

## E. Pricing & payment (parallel, **non-gated** — never blocks processing)

- **Rates/fees** ✅ — `service_rates` + `pricing_settings` (admin-editable in Settings, migration `0030`).
- **Computation** ✅ (`src/lib/pricing.ts`): `Σ rate × containers per service` (VAT-exclusive) + `VAT` on the vatable portion + flat `admin/service fee` + flat `print fee` = Total. Shown on the **payment page** and the standalone **Rate Calculator** (`/calculator`, Home card + nav).
- **Payment** ✅ (migration `0036`) — `/job-order/:id/pay`: computation + KTC **bank/GCash details + QR** (admin-editable in Settings → "Payment details") + **deposit-slip upload** (`payment-slips` bucket, per-user, auto-compressed) → staff **confirm/reject** on the admin queue (`review_payments` gate; reject requires a customer-visible note; customer re-uploads). `payment_status`: `unpaid → submitted → confirmed | rejected`. No gateway.
- **Invoice link** ✅ (`0035`) — cashier records `service_invoice_no` = **PAID** (final word; an in-app payment confirmation doesn't replace it). The official **Service Invoice + BIR receipt come from the ERP**, not this app (operational-only, #5).

## F. External systems

- **KTC ERP** — official invoice/receipt; not linked yet (future integration). Cross-ref = `service_invoice_no` on the JO + the JO number written on the ERP invoice.
- **Google Sheets** — ✅ one-way **app→Sheet mirror for BOC** built (hourly Edge Function + pg_cron, see [[BOC Sheets Mirror]]; awaiting the Google service-account credentials). **No live two-way sync** (Supabase stays source of truth). Internal Sheets data entry replaced by the in-portal Checker station.
- **Vessel schedules (next phase)** — staff sheet-upload → validated import → schedule board; see [[Vessel Schedule Monitoring]].

## G. Open decisions to close before final build (❓)

1. ~~`on_hold` → customer response/update path~~ ✅ built (`0034`).
2. ~~`rejected` recovery: recoverable vs terminal~~ ✅ built (`0034`, admin's call at reject time).
3. ~~Cancel own order~~ ✅ built; full **edit** still deferred (serving-number effects, #8).
4. Admin/employee **filing surface + JO-Processing tile** still open. ~~Employee role~~ ✅ built (`0035`): **staff roles** `admin` / `cashier` / `checker` with an **owner-only permission-gate matrix** (`role_permissions`, Settings → "Roles & gates"; enforced via `has_permission()` in RLS + RPCs, restricted roles are NOT `is_admin`). **X-ray Checker station** ✅ (`/admin/checker`, tablet-first): pending-X-ray queue + container/JO **clearance lookup** ("is this van cleared?") + confirm-done → stamps `xray_performed_at` and completes the JO (`record_xray`).
5. Payment build + bank details/QR values — see [[Payment & Cashier Handoff (proposal)]] (parked for ops audit). ~~`service_invoice_no` + paid state~~ ✅ built (`0035`): cashier (or admin) records the ERP **Service Invoice no.** on a completed JO (`record_service_invoice`) → **PAID** chip; decided flow: ERP invoice carries the JO number for cross-reference.
6. ~~Notifications~~ ✅ lean set built (`0034`): emails on **`on_hold` + `rejected` only** (action-required; Resend-quota-friendly); completed/processing are in-app (auto-poll). Plus an admin **chat status-message generator** (Copy / Viber / SMS) per JO.
7. Go-live: finalize Customer Agreement (counsel, bump `AGREEMENT_VERSION`), run **ST02** on live, public-launch hardening.

## Related
- [[Job Orders]] · [[Brokers]] · [[Pending Items]] · [[Current State]]
- ADR-0012 (held lifecycle) · ADR-0013 (account self-service) · ADR-0014 (processing + slip)
- Migrations `0016`–`0019` (held/caps), `0028`–`0029` (reverify/processing), `0030` (pricing)
