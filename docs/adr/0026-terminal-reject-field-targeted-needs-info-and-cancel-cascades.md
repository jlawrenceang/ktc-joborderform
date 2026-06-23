# ADR-0026: Make reject terminal, on-hold field-targeted, and cascade cancellations from consignee/customer rejection

* Status: Accepted
* Deciders: Owner (Jan Lawrence Ang)
* Date: 2026-06-23
* Category: Workflow | Database

## Context and Problem Statement

The job-order lifecycle (ADR-0014, ADR-0016) modeled `rejected` as a *soft-terminal* state with an optional customer "fix & resubmit" recovery, and `on_hold` as a single free-text "info needed" note. Testing surfaced three problems: (1) a customer responding to an on-hold order saw one note and had to *infer* which field to fix; (2) the recoverable-reject path blurred the line between "rejected" (we won't process this) and "needs info" (fix it and come back); (3) rejecting a **consignee** left the job orders that referenced it dangling (they rendered "no consignee"), and suspending/rejecting a **customer** cancelled only their *held* orders — leaving live ones in flight. How should the lifecycle model rejection, needs-info, and the cascade from consignee/customer status changes?

## Decision Drivers

* Clarity — a customer fixing an order should know *exactly* which fields to re-enter.
* Separation of intent — "rejected = closed, file a new one" vs "needs info = fixable, come back".
* Data integrity — an invalid consignee or a suspended/rejected customer must not leave open job orders running.
* Financial integrity — never auto-cancel an order that is already paid or has an ERP invoice on file.
* Backend-enforced — which fields are editable on resubmit must be enforced server-side (customers have no `job_orders` UPDATE policy).

## Considered Options

* **A — Terminal reject + field-targeted on-hold + cancel cascades.** Reject is final (no customer resubmit, reason shown). On-hold carries `needs_fields`; staff flag which of consignee/entry/vessel/containers must be re-entered; a dedicated resubmit RPC applies *only* those fields. Rejecting a consignee, or suspending/rejecting a customer, cancels their open JOs — except those already paid/invoiced.
* **B — Keep the status quo** (recoverable reject + generic on-hold note) and clean up orphaned/in-flight orders manually.
* **C — Collapse `rejected` into `cancelled`** and keep a generic needs-info note.

## Decision Outcome

Chosen option: **A**, because it is the only option that makes the customer's correction path unambiguous *and* closes the data/financial integrity gaps, with the field-lock enforced server-side. Implemented in migrations `0152` (consignee-reject cascade), `0153` (customer suspend/reject cascade), and `0154` (terminal reject + `job_orders.needs_fields` + `hold_job_order` + `resubmit_needs_info`). Reject now always sets `rejected_recoverable = false`; corrections flow exclusively through the field-targeted needs-info path.

### Positive Consequences

* The customer sees the exact fields to fix; everything else is locked (the resubmit RPC ignores values for unflagged fields).
* Clean separation — `rejected` is a dead-end with a reason; `on_hold` is the recoverable, field-scoped path.
* No orphaned or in-flight orders after an invalid consignee or a suspended/rejected customer.
* The paid/invoiced exclusion protects money already collected; each cascade-cancel records a customer-visible reason.

### Negative Consequences / Trade-offs

* New surface: a `needs_fields` column and two new RPCs (`hold_job_order`, `resubmit_needs_info`).
* Cascade-cancel is irreversible — mitigated by the paid/invoiced exclusion, the reason note, and the customer seeing why.
* `rejected` is now a true dead-end; a mistakenly-rejected order can't be revived (staff must use needs-info instead, or the customer re-files).

## Pros and Cons of Options

### A — Terminal reject + field-targeted on-hold + cascades

* Good, because the correction path is explicit and server-enforced.
* Good, because it removes the orphaned-JO and in-flight-on-suspend gaps.
* Bad, because it adds a column + two RPCs and makes reject unrecoverable.

### B — Status quo + manual cleanup

* Good, because no new code.
* Bad, because customers keep guessing which field to fix, and orphaned/in-flight orders persist and must be hand-cleaned.

### C — Collapse rejected into cancelled

* Good, because fewer statuses.
* Bad, because it loses the staff "we rejected this (with reason)" intent vs a customer self-cancel, and still doesn't give field-targeted needs-info.

## Related ADRs

* Extends [ADR-0014](0014-admin-job-order-processing-and-printable-slip.md) (admin JO processing) and [ADR-0016](0016-staff-roles-split-gates-two-gate-completion.md) (split gates / two-gate completion).
* Interacts with [ADR-0018](0018-additional-charge-supplements-under-review.md) (supplements are part of the "paid" check the cascade exclusion honors).

## References

* Migrations `0152`–`0154` (`supabase/migrations/`).
* `src/pages/MyJobOrders.tsx` (customer needs-info resubmit), `src/admin/AllJobOrders.tsx` (field-targeted Hold), `src/admin/Consignees.tsx` (review).
