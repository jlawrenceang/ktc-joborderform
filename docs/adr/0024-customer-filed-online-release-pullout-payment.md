# ADR-0024: Customer-filed online release / pull-out payment (DO/BL doc verification → payment order → OR)

* Status: Accepted
* Deciders: KTC project stakeholders (owner)
* Date: 2026-06-21
* Category: Architecture | Database | Workflow

## Context and Problem Statement

Pulling a container out of the terminal today is an offline, at-the-window process. The owner wants customers to start it **online through the portal**: a customer uploads their **Delivery Order (DO) or Bill of Lading (BL)** for document verification, KTC creates a **payment order** for the terminal charges, the customer **pays online**, and then **claims the Official Receipt (OR) at the office for pull-out**.

This is the **container release / billing flow** — distinct from the Job Order. Per [ADR-0022](0022-gate-pass-is-container-eir-not-job-order.md), **most containers have no JO** (the JO is a *service overlay*); release/pull-out applies to **every** container. So this needs its own entity and lifecycle, and it is the first customer-facing slice of the container/release spine. The question: what is the data model, who verifies, and how is the amount set — without blocking on the (unbuilt) EIR spine or an ERP integration?

## Decision Drivers

* Release applies to all containers, not the JO'd subset — it must be its own entity, not an extension of `job_orders`.
* The ERP stays the system of record for amounts and the official OR — the app is operational (capture + route), not the billing authority.
* Reuse what exists: the consignee master-list picker, the private-file upload + in-app viewer pattern (valid-IDs / payment-slips), and the payment-proof + QRPH + cashier-confirm flow.
* Owner-tweakable role gates (role_permissions) — the new verification step must be an assignable gate.
* Ship value now without waiting on the EIR/container spine or ERP integration.

## Considered Options

* **Entity:** (A) extend `job_orders` with a "release" type · (B) a new `release_orders` table. → **B**, because release is broader than and independent of the JO (ADR-0022); overloading the JO would muddy both lifecycles.
* **Amount:** (A) **staff assess / enter the total** · (B) compute in-app from terminal rates + storage days · (C) pull from the ERP. → **A** for v1 (B/C deferred — B needs a full rate+storage-day model; C needs ERP integration).
* **Doc verifier:** CSR (documents desk) · Operations · Cashier · new role. → **CSR** (they already field customer documents/questions).
* **Shipment identity:** container no(s) + BL · upload-only · **consignee picker + BL no. + upload**. → the last, reusing the consignee master list and giving structured data.

## Decision Outcome

A new **`release_orders`** module, customer-filed, separate from `job_orders`:

1. **File (customer):** pick consignee (master-list picker) + enter **BL number** + upload **DO/BL** to a private `release-docs` bucket (per-user RLS, same pattern as valid-IDs).
2. **Document verification (CSR):** a CSR "documents desk" queue verifies or rejects the DO/BL, gated by a new owner-tweakable **`verify_release_docs`** permission (CSR + admin; owner bypasses). Reuses the sortable-queue + in-app file-viewer patterns.
3. **Charges (staff assess/enter):** after verification, the release desk enters the **total amount** (transcribed from the ERP / assessed) — no in-app rate calc, no ERP integration in v1. The order becomes **payable**.
4. **Pay (customer):** reuse the existing payment-proof upload + **QRPH** + **cashier-confirm** flow.
5. **OR / pull-out:** on payment confirmation the customer **claims the OR at the office**; the `or_number` is recorded (like `service_invoice_no` on the JO). State → **released**.

**Lifecycle:** `submitted → docs_verified → payable → paid → released`, with `on_hold` / `rejected` (recoverable) branches. Backend-enforced via SECURITY DEFINER RPCs + `has_permission()`, mirroring the JO model.

**Relationship to the JO / EIR spine:** v1 stands alone, keyed by consignee + BL + uploaded docs. When a container in the release *also* has a JO, a later phase cross-references the JO's "cleared for release" (the two-gate) so the release converges with X-ray/service clearance — and ultimately with the deferred gate/EIR module (ADR-0022). Container-grain + EIR linkage is **deferred**.

### Positive Consequences

* Correct home: release is its own entity covering all containers, not bolted onto the JO.
* Fast to build — reuses consignee picker, doc-upload/viewer, and the payment-proof/QRPH/cashier-confirm flow; no ERP or EIR dependency for v1.
* The `verify_release_docs` gate slots into the existing owner-tweakable Roles & Gates.
* It's the concrete first slice of the container/release spine the north star calls for.

### Negative Consequences / Trade-offs

* Amounts are manually entered (transcription risk) until in-app rate computation or ERP integration lands.
* No container-grain or EIR linkage yet — a release references the BL/consignee + documents, not (yet) specific container/EIR records.
* The OR remains an at-office, ERP-issued artifact — online is advance payment + proof, not a fully online receipt.

## Related ADRs

* Extends [ADR-0022](0022-gate-pass-is-container-eir-not-job-order.md) — the container/release spine; this is its first customer-facing slice.
* Reuses [ADR-0021](0021-cashier-station-walk-in-payment-consolidated-email.md) / the payment-proof + cashier-confirm flow.
* Relies on the owner-tweakable role gates (role_permissions) for `verify_release_docs`.

## References

* Decisions captured 2026-06-21 (owner): staff-enter charges · CSR doc verification · consignee + BL + DO/BL upload.
* Reuse: `src/components/SearchPicker.tsx` (consignee picker), `src/components/FileViewerModal.tsx` (doc viewer), `src/pages/Payment.tsx` (payment-proof + QRPH), `src/components/XrayQueueTable.tsx` (queue pattern).
* Phasing — P1: file + CSR verify + charges. P2: payment + cashier confirm + OR/released. P3: JO "cleared for release" cross-link + container/EIR grain.
