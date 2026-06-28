---
title: Additional-Charge Supplements
tags: [concept, job-orders, payments]
type: concept
last_updated: 2026-06-28
---

# 🧾 Additional-Charge Supplements (JO-####-A/B/C)

After a Job Order is filed (or even completed), extra charges can come up — re-inspection, extra moves, a correction. Rather than reopen the base computation, **operations requests an additional charge and the cashier bills it** (ADR-0035 `0176`): a lightweight additional-charge line attached to the main JO, with its **own** amount, payment slip, and confirmation. Introduced in **`0101`**; the customer-facing "needs action" flag in **`0104`**; the request→bill split in **`0176`**.

## Model — `jo_supplements`

- `suffix` (A, B, C…, auto from the count — numbered **JO-<no>-A / -B / -C**), `label`, `amount`.
- Its own payment lifecycle: `payment_status` `unpaid → submitted → confirmed | rejected`, `payment_proof_path`, `payment_note`.
- RLS: read = `view_job_orders` staff **or** the owning customer; **all writes via RPCs**.

## RPCs

- **`request_supplement(jo, label)`** — operations (`request_supplement`, `0176`). Label only, **no amount** — creates a `bill_status = 'requested'` line (not yet a payable); notifies the cashier.
- **`bill_supplement(id, amount)`** — cashier (`bill_supplement`, `0176`). Sets the amount → `bill_status = 'billed'` (the payable) + notifies the customer.
- **`add_supplement(jo, label, amount)`** — direct add-and-bill, **re-gated from `process_job_orders` (ops) to `bill_supplement` (cashier/admin)** in `0176`; marks the supplement `billed` immediately. Blocks on `cancelled`/`rejected`/`held`.
- **`submit_supplement_proof(supp, path)`** — customer uploads a slip (per-user path check) → notifies the payments desk.
- **`review_supplement_payment(supp, confirm, note)`** — cashier (`review_payments`) confirms/rejects (reject needs a note).
- **`record_supplement_office_payment(supp)`** — cashier records a walk-in payment.

## Under review (the un-complete / re-complete loop)

Adding an **unpaid** supplement to an **already-completed** order bounces it back: `status → processing`, `completed_at` cleared. This shows as **"Under review"** on admin + customer rows and a banner on the pay page. The order **auto-re-completes** the moment the last outstanding charge is confirmed (the supplement-review RPCs call `jo_ready_to_complete`). See [[Two-Gate Completion]].

## Completion gate

Supplements are part of the release gate: `jo_ready_to_complete` + `enforce_two_gate_complete` require **no billed-but-unpaid** supplement (`bill_status = 'billed'` AND `payment_status <> 'confirmed'`, `0181`). A charge that ops only **requested** (not yet billed) does not block, and a **free re-X-ray** child is exempt entirely. So a JO with a billed, unsettled charge cannot complete or be released.

## Customer "needs action" (`0104`)

"Has an outstanding supplement" is a cross-table condition PostgREST can't express in a parent `.or()` filter, so it's **denormalized** onto `job_orders.has_open_supplement`, set only by **billed-unpaid** supplements (`0182`) and kept in sync by an INSERT/UPDATE trigger (`sync_open_supplement`) on `jo_supplements`. My Job Orders' Needs-action filter reads the boolean. The trigger touches only that column, so it does **not** trip the two-gate completion trigger.

## UI

- **Operations** — "Request charge" on the admin JO card (creates a `requested` line; no amount).
- **Cashier / admin** — "Add charge" (direct add-and-bill) on the JO card, and **bills** ops-requested charges in the [[Cashier Station]].
- **Customer** — each billed supplement is its own pay section on `/job-order/:id/pay`.
- **Cashier** — a 4th section in the [[Cashier Station]] reviews/collects supplement payments.

## Related

- [[Two-Gate Completion]] · [[Job Order Lifecycle]] · [[Cashier Station]] · [[Job Orders]]
- Migrations `0101` (supplements + under-review), `0104` (open-supplement flag), `0176` (ops-request → cashier-bill split), `0181` (gate on billed-unpaid only), `0182` (flag set by billed-unpaid only)
