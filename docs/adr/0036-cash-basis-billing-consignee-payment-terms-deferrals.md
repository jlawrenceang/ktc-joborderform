# ADR-0036 — Cash-basis billing, consignee payment terms, and deferred ERP / auto-tariff / credit

**Status:** Accepted
**Date:** 2026-06-28
**Deciders:** Owner (Jan Lawrence Ang)
**Related:** [ADR-0035](0035-job-order-ops-overhaul-queue-priority-rexray-autocomplete-invoice-gate.md) · break-test backlog `docs/audits/2026-06-28-breaktest-findings.md` (T2-29/30/31/35/36, KTC-32) · [[rate-matrix-and-calculator]] · [[storage-tiered-tariff]]

## Context

The break-test + audit surfaced three large, decision-heavy billing items that were holding up Phase 2 planning:
1. **ERP (Frappe) API integration** (T2-35) — currently the cashier types the ERP control number by hand; there's no programmatic create/verify/paid-callback.
2. **Terminal-tariff → billing bridge** (T2-29/30/31) — the terminal/storage tariff matrix (`terminal_rates`/`storage_tiers`) is calculator-only; it produces an *estimate*, never an actual charge. Auto-computing **storage** needs a days-in-yard count, i.e. gate-in/gate-out timestamps — the **gate/EIR module**, which is future scope (north-star / Phase 5).
3. **Credit / on-account (BI-INV)** billing (T2-17/36) — releases + JO completion are wired cash-first; credit is partially stubbed.

These needed an owner call before building, to avoid speculative work.

## Decision

- **Cash-to-cash basis only, for now.** Pay-before-release / pay-before-complete stays the model. No credit billing path is built yet.
- **Add a `payment_terms` flag on consignees** (`cash` | `credit`, **default `cash`**), set on the consignee add/edit form + shown on the admin consignee view. This makes the data model credit-ready without committing to the credit *flow* — credit can be switched on later without a migration scramble.
- **Release / pull-out billing is a manual cash loop** (no auto-tariff bridge): customer **requests a bill** (files the release/pull-out request) → cashier **computes the charge** (storage + terminal, manually from the tariff) + **uploads the bill document** + sets the amount → customer **uploads proof of payment** → cashier **confirms** → records the OR → released. (Adds a bill-document upload + void/edit to the existing release-charge step.)
- **Defer:** (a) **ERP API** — pending a go-signal from Titus; keep manual control-number entry. (b) **Terminal-tariff auto-bridge** — pending the gate/EIR module (no day-count source); the calculator stays estimate-only and the release desk computes charges manually. (c) **Credit/BI-INV flow** — deferred behind the `payment_terms` flag.
- **KTC-32** (`verify_job_order` public disclosure) — left as-is pending an owner call (may be intentional per ADR-0019).

## Consequences

- **Positive:** launch stays lean + cash-only (matches current KTC ops); no speculative ERP/gate work; the consignee `payment_terms` flag means turning on credit later is additive; the manual release-billing loop is fully buildable now without the gate module or ERP.
- **Negative / residual:** storage/terminal charges are typed by a human (transcription risk; mitigated by the bill-document upload + void/edit); the ERP control number remains unverified until the API lands; credit customers can't self-serve on account yet.
- **Revisit when:** Titus greenlights the ERP API; the gate/EIR module ships (unblocks auto-tariff storage); or credit billing becomes a real customer need.

## Alternatives considered

- **Build the auto-tariff bridge now** — rejected: storage needs gate timestamps that don't exist yet; would be guesswork or force premature gate-module work.
- **Build credit now** — rejected: no immediate need; cash-only matches current ops; the flag keeps it cheap to add later.
- **Integrate the ERP API now** — rejected: no go-signal from Titus; needs credentials + an architecture decision out of our control.
