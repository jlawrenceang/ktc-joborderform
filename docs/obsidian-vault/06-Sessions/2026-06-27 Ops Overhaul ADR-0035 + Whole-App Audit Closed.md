---
title: 2026-06-27 Ops Overhaul (ADR-0035) + Whole-App Audit Closed
tags: [session, job-orders, audit, ops-overhaul]
type: session
date: 2026-06-27
---

# 2026-06-27 — Ops Overhaul (ADR-0035) + Whole-App Audit Closed + Framework Expansion

A very large session: the **consignee approval gate**, the **7-phase job-order ops overhaul** ([ADR-0035](../../adr/0035-job-order-ops-overhaul-queue-priority-rexray-autocomplete-invoice-gate.md)), and a **whole-app ultracode audit (59 findings) fixed + closed**. `APP_VERSION` v1.6.52 → **v1.6.73**; migrations `0165` → **`0183`** (all applied to prod). See [[whole-app-audit-closed]] (memory) + `CHANGELOG.md` v1.6.52–73.

## Consignee approval gate + full CIS (v1.6.53–57, `0165`–`0169`)
The consignee request flow was rewired around a **clear approval gate** (mirroring the ID-verification gate — "no limbo"): a consignee must be **approved before it can be used to file**. The full **Customer Information Sheet** is captured online (`request_consignee` 10-arg, `0166`) or printable blank; staff see **documents / incomplete-info badges**. The **BIR 2303 rule is hard-enforced on every path** — admin add, CSV, customer request, resubmit, and the approval guard (`guard_consignee_approval` restored in `0167`). JO filing refuses an unapproved consignee (`guard_job_order_consignee_approved`, `0169`); the customer resubmit form was synced to the full CIS (`0168`). Also: notifications **"Clear read"** (`0165`) + the test account reset to fresh pending. See [[Consignees]].

## Job-order ops overhaul — ADR-0035, phases 1–7 (v1.6.59–65, `0170`–`0177`)
A full operational-lifecycle pass (see [[Job Order Lifecycle]], [[Staff Roles & Gates]]):
1. **Role grants + separation-of-duties** — CSR no longer approves orders (closes a maker-checker gap), cashier trimmed to money-only (`0171`).
2. **Fully automatic completion** — completes from whichever side finishes last (services *or* payment): `complete_on_service_done` (`0172`) beside `complete_on_payment_confirmed`.
3. **Automatic queue lifecycle** — serving numbers assign on submitted/processing, vacate on hold/reject/cancel/complete (`0173`).
4. **Priority lane** — a separate P-numbered lane; request → admin approve (`0174`).
5. **Re-X-ray lane** — a separate queue for a completed order's re-inspection; checker/ops request → admin approve; a child JO with an `A` suffix; free now, billable-capable later (`0175`).
6. **Charges = ops-request → cashier-bill** (`request_supplement`/`bill_supplement`, `0176`).
7. **Payment-requires-invoice** — base payment can't confirm without the ERP service invoice + BIR pad serial on file (`0177`).

## Whole-app ultracode audit → fixed + CLOSED (v1.6.66–73, `0178`–`0183`)
A **75-agent ultracode audit** surfaced **59 verified findings** (11 high), several introduced by the overhaul. All **live-impact findings are fixed**; a **closure workflow** re-verified every remaining one and caught **1 regression I'd introduced** (a CashierStation `peso(null)` crash) — fixed. Highlights: the office-payment **invoice-gate side-door** + the cashier deadlock, `confirm_release_payment` reviving a **cancelled release**, **staff-only notes leaking** to customers, **re-X-ray** notification leaks + maker-checker bypass + edit/cancel guards + a suffix race, the **completion-breaking** billed-supplement gate, **phantom balances** from un-priced charges, **lane-tagged + priority-served** serving numbers, **vessel dedup data-loss** + the free-text join, **fuel pricing readable by anon**, and the stale "you can file" copy. `check-security-invariants` green throughout. Only deferral: the **parked fuel module's** 5 findings → the Phase-1 fuel desk (no live UI). See [[whole-app-audit-closed]].

## Also
- **Earlier polish** (v1.6.46–52): the walkthrough video embedded in the Quick tour (MP4), the Lara avatar + typing animation, the admin Actions-menu mobile-clip fix.
- **Framework** (`jla-framework` repo, deployed to `~/.claude`, now **private**): new skills `deck-generator` (markdown → self-contained interactive HTML deck), `sms-gateway` (free SMS recipe + Edge Function template), `reference-triage` (the owner's dual-lens reference rule); lifted principles (placement-salience, autonomous-fleet doctrine, expiry-tagged memory, the reference/knowledge-pack skill type, specificity-over-adjective, codegraph defer-rule); ~14 references triaged (most rejected as catalogs/off-domain).

## Carried forward
- The **Phase-1 fuel desk** (build the 5 deferred fuel findings WITH it).
- A full step rewrite of [[Job Order Lifecycle]] (it carries a dated correction note; the model is current, the prose still reflects `0156`).
- Pre-go-live: re-enable Turnstile + MFA, owner-password rotation, ST05 lanes, Agreement v4 counsel sign-off (`docs/go-live-todo.md`). i18n: Tagalog for the new admin/audit strings (English fallback works).
