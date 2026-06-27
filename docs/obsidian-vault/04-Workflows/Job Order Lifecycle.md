---
title: Job Order Lifecycle
tags: [workflow, job-orders, lifecycle]
type: workflow
status: live
last_updated: 2026-06-27
---

# 🔄 Job Order Lifecycle (source of truth)

> Status legend: ✅ built · 🔸 decided, not yet built · ❓ open decision.
> Reflects migrations through **0156**. For the staff role model see [[Staff Roles & Gates]];
> for the completion rule see [[Two-Gate Completion]].
>
> ⚠️ **2026-06-27 — superseded in part by the ADR-0035 ops overhaul (`0170`–`0177`) + the
> whole-app audit closure (`0178`–`0183`). Current model:** pending brokers are **verify-only**
> (can't file — ADR-0032; the "pending files held" flow is retired); **completion is automatic**
> once both gates clear; the serving queue has **priority** + **re-X-ray** lanes (request → admin
> approve), lane-tagged P-/R-/# numbers with priority served ahead; **charges** are ops-request →
> cashier-bill; and **payment-confirm requires the ERP + BIR invoice on file**. Source:
> **ADR-0035** + [[whole-app-audit-closed]]. A full step-by-step rewrite of the steps below
> stays carried-forward (the model here is current; the steps still reflect `0156`).

## Actors

- **Customer** (customs broker) — files JOs against consignees, pays online, comments.
- **Staff roles** (one permission-gated matrix, [[Staff Roles & Gates]]):
  - **operations** — accepts orders, assesses RPS, marks DEA/OOG services done, tags additional charges, monitors X-ray, completes; edits JO header.
  - **checker** — confirms **X-ray per van** (BOC performs the X-ray; the checker confirms entry to the X-ray division). View only otherwise.
  - **cashier** — reviews payments (online proof + walk-in), records the ERP invoice, completes once paid; edits JO header.
  - **csr** — files JOs for customers + works the support inbox; **never** changes order status.
  - **admin** — the full back office (all gates except X-ray confirmation, dropped in `0095`).
- **Owner / root owner** — superset of admin; bypasses every gate via `has_permission`; server-only failsafe. See [[Owner Failsafe]], [[Multi-Owner & Root Grants]].
- **KTC ERP** (external, not linked yet) — produces the official **Service Invoice + BIR receipt**.

## A. Account lifecycle (prerequisite) ✅

`register` (name + contact + email + password + consent + CAPTCHA) → `confirm email` → sign in **`pending`** → upload valid ID at `/verify-id` → admin **approve** (releases held orders, deletes ID) / **reject** (recoverable: resubmit) / **suspend** (terminal). 48h TTL auto-rejects no-ID pendings. Signup refuses an email that already has an account (`0098`-era, 1 email = 1 account). *(ADR-0012, ADR-0013.)*

## B. Job Order states

| State | Meaning | Notes |
|---|---|---|
| `held` ✅ | Filed by a **pending** (unverified) customer | Queue-hidden; ≤10; **no JO number yet** ("Draft") |
| `submitted` ✅ | Live in the admin queue | JO number assigned; **gets a priority number** (one per JO, see §D) |
| `processing` ✅ | Being worked (accepted, or partially X-rayed) | Printable slip; "ON PROCESS" / PENDING watermark |
| `on_hold` ✅ | Staff needs info | Customer-visible `admin_note`; `needs_fields` array flags which fields (consignee/entry/vessel/containers) customer must re-enter; customer responds via field-targeted resubmit |
| `completed` ✅ | Done — **passes the two-gate** (all services + all payments) | Clean slip with COMPLETED watermark + verify QR |
| `rejected` ✅ | Staff declined — **terminal** | Customer-visible `admin_note`; final (no customer resubmit; use `on_hold` → field-targeted path instead) |
| `cancelled` ✅ | Customer-cancelled or auto on account suspend/reject | |

**Under review** ✅ (`0101`) is not a separate state — it is a `completed` order bounced back to `processing` (with `completed_at` cleared + `has_open_supplement = true`, `0104`) because an additional charge ([[Additional-Charge Supplements]]) was tagged after completion. It auto-re-completes once the charge is paid.

## C. Transitions (who triggers — server-enforced)

The explicit staff actions go through **`staff_transition_order(p_id, p_status, p_note, p_recoverable)`** (`0086`/`0097`), which checks the split gate for the target status. The old admin-only direct UPDATE is gone.

- **File** (customer / CSR) → `held` (pending) or `submitted` (approved). ✅ Filing is atomic (`0098` — no orphan orders).
- **File on behalf** (operations/CSR/admin) → `submitted`. ✅ (`/admin/new-job-order`, `file_job_orders`; staff filings bypass caps.)
- **Account approved** → that customer's `held` → `submitted` (release trigger). ✅
- **Accept** → `submitted` / `on_hold` → `processing`. Gate **`accept_orders`** (operations / admin).
- **Hold for info** (+note, +field list) → `submitted` / `processing` / `on_hold` → `on_hold`. Gate **`hold_reject_orders`** (operations / cashier / admin). **`hold_job_order()`** sets `needs_fields` (subset of consignee/entry/vessel/containers) to flag which fields the customer must re-enter; empty set = general hold (note only).
- **Reject** (+note) → open → `rejected`. Gate **`hold_reject_orders`**; **always terminal** (`rejected_recoverable = false`). ✅ (`0154`)
- **Complete** → open → `completed`. Gate **`complete_orders`** (operations / cashier / admin) **AND** the [[Two-Gate Completion]] readiness must hold; otherwise raises. Usually auto-fired (see D/E) rather than clicked.
- **Respond to hold with field-targeted resubmit** (customer) → `on_hold` → `submitted`. ✅ **`resubmit_needs_info()`** enforces field-lock server-side (only updates flagged fields in `needs_fields`; other values ignored). (`0154`)
- **Edit own order** (customer) → content change while `held`/`submitted`. ✅ (`update_job_order`; locks at `processing`+.)
- **Staff edit header** (`0103`) → consignee / entry / vessel / voyage / vessel-visit on any non-cancelled/-rejected order. Gate `process_job_orders OR review_payments OR manage_support` (operations / cashier / CSR — **checker excluded**, **customers excluded**). `staff_edit_job_order`.
- **Cancel** (customer) → `held` / `submitted` / `on_hold` → `cancelled`. ✅ (not once `processing`.)
- **Cascade-cancel on consignee reject** → When a consignee is rejected (`0152`), all open JOs referencing it (`held`/`submitted`/`processing`/`on_hold`) are auto-cancelled **except** those already paid or invoiced (financial integrity). Customer-visible reason in `admin_note`.
- **Cascade-cancel on customer suspend/reject** → When a customer is suspended or rejected (`0153`), all their open JOs (`held`/`submitted`/`processing`/`on_hold`) are auto-cancelled **except** those already paid or invoiced. Customer-visible reason in `admin_note`.

## D. Numbering & priority

- **JO number `JO-######`** ✅ — **permanent identity**; `ensure_jo_number` on first live status; global, atomic, never reused.
- **Priority queue number** ✅ — generalized in **`0100`**: **ONE priority number per JO** (`serving_numbers.service_line = 'queue'`), assigned on `submitted`, **weekly reset** (Mon, Asia/Manila). Replaces the old per-line xray/dea/oog serving numbers (re-compartmentalizable later).
  - **Edit / respond-to-hold** → keeps its number (active number is never reassigned). **Cancel / reject** → vacated (burned, unreusable). **Resubmit after reject** → back of line; admin **"↩ Restore #N"** (same week).
  - Surfaces: `now_serving()` board (My Job Orders + stations), priority chip on cards, the A6 slip.

## E. Services & per-van X-ray

- A JO has one or more **service lines** (X-ray / DEA / OOG / other). "All services done" = every distinct service line recorded in `service_completions`.
- **DEA / OOG / other** → `record_service_done` (gate `process_job_orders` — operations/admin).
- **X-ray = per van** ✅ (`0087`/`0088`/`0095`): each container line has `xray_done_at/by/by_name`. **`record_van_xray(line_id)`** confirms one van — gate **`confirm_xray` = Checker only** (operations lost it `0087`, admin lost it `0095`; owner still bypasses). The **name is snapshotted immutably** (e-signature on the slip). When the **last** X-ray van is confirmed, the X-ray service line rolls up done (`record_service_done`), which applies the two-gate.

## F. Pricing & payment (parallel — never blocks processing, but **gates completion/release**)

- **Rates/fees** ✅ — `service_rates` + `pricing_settings` (`manage_pricing`); terminal tariff (`terminal_rates`, `0073`/`0078`) + per-line **charge rules** (`shipping_line_charge_rules`, `0080`: waive/discount%/discount₱/surcharge₱); per-move **RPS rates** (`move_rates`, `0062`). Standalone **Rate Calculator** `/calculator` (guided estimate).
- **Base payment** ✅ — `/job-order/:id/pay`: computation + KTC **bank/GCash + QR** + **deposit-slip upload** (`payment-slips` bucket) → cashier confirm/reject (`review_payments`; reject needs a note). `payment_status`: `unpaid → submitted → confirmed | rejected`.
- **RPS (port-services)** ✅ (`0062`/`0063`): operations **assesses** (`assess_rps`) whether the JO `needs` RPS, uploads the RPS doc + per-move quantities (`rps_moves`); each move bills at a VATable per-move rate on top of the base. RPS has its **own** payment slip + confirm (`rps_payment_status`).
- **Walk-in / office payment** ✅ (`0091`): cashier marks base or RPS paid at the window without a proof (`record_office_payment`, `review_payments`) — we still nudge online to skip the line. Supplements have the same walk-in path (`record_supplement_office_payment`).
- **Additional-charge supplements** ✅ (`0101`) — see [[Additional-Charge Supplements]]: JO-####-A/B/C extra charges, each with its own amount + slip + confirm; the customer pays each as its own section on the pay page; the cashier reviews/collects them in a 4th Cashier-station section.
- **Invoice link** ✅ — cashier records `service_invoice_no` (ERP) = **PAID** (final word; an in-app confirmation doesn't replace it). The official Service Invoice + BIR receipt come from the ERP.

## G. Completion gate (two gates + RPS + supplements) ✅

See [[Two-Gate Completion]]. An order may reach `completed` **only** when **ALL** of:
1. every service line is done (incl. all X-ray vans), AND
2. base `payment_status = 'confirmed'`, AND
3. RPS is `not_needed` OR `rps_payment_status = 'confirmed'`, AND
4. **every supplement** is `confirmed`.

Enforced in `jo_ready_to_complete()` + the `complete_on_payment_confirmed` BEFORE-trigger (auto-fires when the **last** payment of base/RPS/supplement lands) + the `enforce_two_gate_complete` raw-update backstop + `staff_transition_order`. Whoever does the last of "services" / "payments" trips the completion.

## H. Anti-forgery verify-QR ✅

Every slip carries a **QR → `/verify/:id`** (public, anon `verify_job_order`). See [[Verify-QR Anti-Forgery]]. Slip watermark = PENDING (open) / COMPLETED. The verify page shows JO number, status, **PAID badge** (reflects base + RPS), completion date, **consignee + container numbers** for a physical cross-check. Foundation for a future guard gate-scan ([[Gate Module (gate-in-out)]]).

## I. Comments & escalation ✅

JO comments live in `job_order_events` (`event = 'comment'`), surfaced only through `jo_timeline`. See [[Comment Visibility & Escalation]]: customer comments are reviewed by CSR; staff can add **`staff_only`** internal notes (never shown to customers) and **flag** a comment as a complaint/escalation. `add_jo_comment` (customer) / `add_jo_staff_note` / `flag_jo_comment`.

## J. External systems

- **KTC ERP** — official invoice/receipt; not linked yet. Cross-ref = `service_invoice_no` + JO number.
- **Google Sheets** — one-way **app→Sheet BOC mirror** (hourly Edge Function + pg_cron; awaiting service-account creds). No live two-way sync.
- **Vessel schedules** — staff-managed schedule board (`manage_vessel_schedule`, `/admin/vessel-schedule`).

## Related
- [[Job Orders]] · [[Administration]] · [[Brokers]] · [[Pending Items]] · [[Current State]]
- [[Staff Roles & Gates]] · [[Two-Gate Completion]] · [[Additional-Charge Supplements]] · [[Verify-QR Anti-Forgery]] · [[Comment Visibility & Escalation]]
- ADR-0012 (held lifecycle) · ADR-0013 (account self-service) · ADR-0014 (processing + slip) · ADR-0026 (reject terminal + field-targeted needs-info + cascades)
- Migrations `0062` (RPS), `0086` (CSR + split gates), `0087`/`0088`/`0095` (per-van X-ray), `0089`/`0090` (verify-QR), `0091` (office payment), `0100` (queue), `0101`/`0104` (supplements), `0102` (comments), `0103` (staff edit), `0152`–`0154` (reject terminal + field-targeted needs-info + cascades)
