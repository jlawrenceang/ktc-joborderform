# ADR-0035: Overhaul job-order ops — automatic queue, priority + re-X-ray lanes, auto-complete, invoice-gated payment, CSR grants

* Status: Accepted
* Deciders: Owner (Jan Lawrence Ang)
* Date: 2026-06-27
* Category: Business Logic

## Context and Problem Statement

Mapping the admin job-order controls surfaced gaps between how ops actually run and what the system enforces: the serving-number queue never released a held order's place, completion was a manual click, payment could be confirmed without an official invoice, there was no way to prioritise an order, and a blurred X-ray had no re-do path. How should the queue, completion, payment, priority, re-X-ray, and the role grants behave?

## Decision Drivers

* Clear gates, no limbo — every state must be one the system can reason about (the principle just applied to consignees, ADR-0029).
* Match real terminal ops: a "now serving" line, priority pushes, re-X-ray on blurred scans, official-invoice-on-payment.
* Backend-enforced access — role grants + request→approve flows live in the DB, not the UI.
* Ship incrementally so each change is verifiable live.

## Considered Options

* Leave queue / completion / payment manual (status quo) — keeps the drift between ops reality and the system.
* One-shot rewrite of every flow — high risk, hard to verify.
* **Phased overhaul** with an explicit gate per concern.

## Decision Outcome

Chosen option: **phased overhaul**, built and shipped in seven phases:

1. **Roles (separation of duties)** — order approval (`accept_orders` / `hold_reject_orders`) stays with **operations + admin**; **CSR** is intake + comms only (file on behalf, support, consignee review, release-doc verify); **cashier** is trimmed to its money lane (`review_payments` + `record_invoice`). *(Revised after the role-permission review: a CSR could file-on-behalf and approve — a maker-checker gap; cashier reached outside money. Migrations 0170 → 0171.)*
2. **Auto-complete** — an order self-completes the moment both gates pass (all services done + base payment confirmed + RPS settled); the manual "Mark completed" button retires.
3. **Queue auto-lifecycle** — active line = `submitted` / `processing`; `on_hold` / `rejected` / `cancelled` / `completed` vacate the serving number (→ 0, off the board); returning to the line gets a NEW number at the tail (never the old one). The manual `restore_serving_number` retires.
4. **Priority lane** — a separate numbering lane (`P-n`) served fully ahead of the regular queue; **requested by CS / operations → approved by admin**; the checker strikes items off as served.
5. **Re-X-ray lane** — only on a completed JO; **requested by checker / ops → approved by admin**; a child of the original with a suffixed number (`JO-000001A`, `B`…) on its own (3rd) queue, running its own lifecycle. **Free now**, with a `billable` flag in the schema for future paid re-X-rays.
6. **Additional-service request** — operations requests an extra charge / service → the cashier reviews, bills it, and creates the payable (ops never bills directly).
7. **Payment → invoice gate** — confirming a payment requires the ERP + BIR invoice numbers on file; recording them *is* the confirm (one step, moved earlier). Nothing reads "paid" without an official invoice.

### Positive Consequences

* The queue behaves like a real now-serving line; priority + re-X-ray are explicit, auditable lanes.
* No "paid but no invoice" or "approved but unverified" limbo.
* Each phase ships independently and is verifiable live.

### Negative Consequences / Trade-offs

* Several migrations touch the serving-number triggers, completion, and payment — sequencing matters.
* A new parent/child JO relationship (re-X-ray) adds modelling surface.

## Pros and Cons of Options

### Phased overhaul

* Good, because each gate ships + verifies on its own; low blast radius per change.
* Good, because it matches the established "clear gate, backend-enforced" pattern.
* Bad, because the full benefit only lands after all seven phases.

### One-shot rewrite

* Good, because internal consistency is settled in a single pass.
* Bad, because it's high-risk and hard to verify or roll back.

## Related ADRs

* Extends [ADR-0016](0016-staff-roles-split-gates-two-gate-completion.md) (staff roles + two-gate completion).
* Extends [ADR-0018](0018-additional-charge-supplements-under-review.md) (additional-charge supplements).
* Builds on the serving-number queue (migrations 0038 / 0100) and [ADR-0032](0032-pending-accounts-verify-only-lockdown.md).

## References

* Session 2026-06-27 — admin-controls scan + flow spec.

## Addendum — 2026-06-27 (audit closure)

A 75-agent whole-app ultracode audit (run after phases 1–7 shipped) found **59 verified findings**, several introduced by this overhaul — all fixed + re-verified by a closure workflow (which caught one regression). Material post-ship hardening of the decisions above, in migrations `0178`–`0183`:

- **Invoice gate (phase 7)** had two holes — the walk-in/office payment path bypassed it, and the cashier station deadlocked (couldn't record the invoice before confirming). Both closed.
- **Re-X-ray (phase 5)** hardened: customer notifications suppressed for the internal child; the maker-checker can't be bypassed via the generic accept path; the customer can't cancel/edit the child; an advisory lock prevents a concurrent suffix collision; and it can't be X-rayed before admin approval.
- **Auto-complete + charges (phases 2/6)** — the completion gate keys on **billed** (priced) supplements only (a requested, un-priced charge no longer blocks completion or shows a phantom balance); billing a charge on a completed order no longer reopens it; ops requests now notify the cashier/admin who must act.
- **Priority (phase 4)** — granted orders are now actually **served ahead** on both checker queues (lane-tagged P-/R-/# numbers); the manual `restore_serving_number` queue-jump this overhaul retired was finally dropped; `review_priority` requires a pending request.

Full record: [[whole-app-audit-closed]] + `CHANGELOG.md` v1.6.66–73. Status unchanged (Accepted) — this documents hardening, not a reversal.

## Addendum — 2026-06-28 (manual "Mark completed" kept as a fallback)

Phase 2 above says the manual **"Mark completed"** button *retires*. In runtime it is **kept as a rare ready-state fallback**, not removed: `src/admin/AllJobOrders.tsx` still renders it, but **only when the order is already two-gate-ready** (`complete_orders` held · `processing` · base paid · RPS settled · all services done). Auto-complete normally fires first, so the click is a no-op safety net rather than a routine action. Treat the design intent as *"completion is automatic; the button is a last-resort fallback,"* not *"the button is gone."* Status unchanged (Accepted).
