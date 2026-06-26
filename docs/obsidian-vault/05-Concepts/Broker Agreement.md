---
title: Broker Agreement
tags: [concept, policy, privacy, security, legal]
type: concept
---

# 📜 Broker Agreement

The single master legal document brokers accept at registration — fuses the former Broker IRR, Terms & Conditions, and Privacy Notice into one, centered on **confidentiality / non-disclosure (NDA)** and the **Data Privacy Act of 2012 (R.A. 10173)**. See ADR-0011 (supersedes the document structure of ADR-0008/0009).

## Where it lives

- **Content (single source):** `src/content/customer-agreement.md` (Markdown). Edit here.
- **Version:** `src/content/legal.ts` → `AGREEMENT_VERSION` (+ `AGREEMENT_VERSION_LABEL`). Bump on material change.
- **Page:** `src/pages/Agreement.tsx` at the **public** `/agreement` route (shared `MarkdownDoc` renderer). The old `/irr`, `/terms`, `/privacy` routes **redirect** here.

## Document sections

Acceptance/eligibility · broker conduct & acceptable use · **confidentiality and non-disclosure** · **data privacy consent (R.A. 10173)** — PIC + DPO, data collected (incl. valid ID), purposes, legal basis, processors (Supabase/Vercel/Cloudflare), disclosure, international transfer, retention, data-subject rights · liability/termination · governing law (PH) + amendments.

## Registration UX + consents (two ticks)

The Agreement is shown **inline in a scrollable box** on the registration form, with a **"View full ↗"** link opening `/agreement`, and **two required checkboxes** below it:

1. **Terms & Conditions** (incl. confidentiality / NDA).
2. **Data Privacy Act consent** (separate tick — DPA good practice; explicitly covers the uploaded valid ID).

Sign-up is blocked until both are ticked (CAPTCHA still applies).

## How acceptance is recorded — server-enforced (`0162`)

Consent is enforced in the **database**, not just the UI (closes the audit's L1 + L2; v1.6.24):
- **One server-stamped writer** — every path (email/password signup, the pending-banner sync, the valid-ID page, the OAuth `FinishRegistration` step) records through **`record_agreement_consent(p_version)`** (or `complete_oauth_registration`). The six consent columns on `customers` are **server-stamped only** — a raw client UPDATE is pinned back by the `customers` guard trigger, gated by a transaction-local `ktc.allow_consent_write` flag only the consent RPCs set (mirrors the `ktc.allow_owner_change` pattern). Acceptance = `AGREEMENT_VERSION` + timestamp (also mirrored to auth metadata).
- **No transaction without recorded consent** — `file_job_order` and `open_ticket` (the SECURITY DEFINER write paths) refuse to run unless `has_recorded_consent()` is true. The gate lives **inside the definer function** (which bypasses RLS); the RLS `WITH CHECK` is kept as defense-in-depth.

## Agreement v4 (2026-06-26)

Redlined after a PH-legal-framework review (DPA, e-Commerce Act, Civil Code, fairness) — `src/content/customer-agreement.md`, `AGREEMENT_VERSION` → **v4.0**:
- **Privacy made truthful** — false NPC-compliance / designated-DPO claims removed; now a genuine commitment + a real contact + a promise to appoint a DPO and register with the NPC. **Owner (Jan Lawrence Ang) named interim DPO.**
- **Liability cap re-pegged to the Service Invoice** (the JO carries no fee → the old cap was illusory): "the greater of trailing-6-months Service-Invoice charges or **₱100,000**."
- **Amendments now require affirmative re-acceptance** for material changes (not passive "continued use") — superseding the old "not yet enforced" caveat, though the in-app re-acceptance gate on a version bump is still a future lane.
- Plus an **authority-to-bind** clause + a **Notices** clause.

## Status / caveats

- Still a **working template pending final PH-counsel sign-off** — NPC registration, dedicated DPO mailbox, and the ₱100k liability floor are owner/counsel items tracked in `docs/go-live-todo.md`.
- A single document mixes instruments (terms + NDA + privacy); counsel may prefer a standalone Privacy Notice for NPC purposes.

## Related

- [[Brokers]] · [[Authentication]] · [[Broker Onboarding]] · [[RLS Posture]] · [[2026-06-26 Public Landing + Lara + Google OAuth + Consent Enforcement]]
- ADR-0008, ADR-0009, ADR-0011 · go-live: `docs/go-live-todo.md`
