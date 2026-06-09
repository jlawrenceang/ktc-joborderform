---
title: Data Privacy and Consents
tags: [concept, policy, privacy, security]
type: concept
---

# 🔏 Data Privacy and Consents

The legal documents brokers accept at registration, and how consent is recorded. Companion to [[Broker IRR]].

## The three documents

All are single-source Markdown rendered via the shared `src/components/MarkdownDoc.tsx`, exposed as **public** routes, and versioned in `src/content/legal.ts`:

| Doc | Content file | Route | Version const |
|---|---|---|---|
| Broker IRR | `src/content/broker-irr.md` | `/irr` | `IRR_VERSION` |
| Terms & Conditions | `src/content/terms-and-conditions.md` | `/terms` | `TERMS_VERSION` |
| Privacy Notice | `src/content/privacy-notice.md` | `/privacy` | `PRIVACY_VERSION` |

## Why a separate privacy consent

Registration uploads a **valid government-issued ID** — regulated personal data under the **Data Privacy Act of 2012 (R.A. 10173)**. Under the DPA, consent to process such data should be **specific and freely given**, so it is captured as its **own checkbox**, not bundled into the Terms.

## Registration consents (two checkboxes)

1. **Terms & Conditions + Broker IRR** — agreement to use the portal and follow broker rules.
2. **Data-privacy consent** — explicit consent to collect/process personal data including the uploaded ID, per the Privacy Notice.

Both are **required**; sign-up is blocked until ticked (CAPTCHA still applies). The Privacy Notice covers: Personal Information Controller + DPO contact, data collected, purposes, legal basis, storage/security + processors (Supabase/Vercel/Cloudflare), disclosure, international transfer, retention, and **data-subject rights** (access, rectification, erasure, objection, portability, NPC complaint).

## How consent is recorded

- **Auth user metadata** (always, even before the migration): `terms_version`, `terms_accepted_at`, `privacy_consent_version`, `privacy_consented_at` (plus the IRR fields from [[Broker IRR]]).
- **`brokers` columns** via migration `0012_broker_consents.sql` (+ `0011` for IRR) — for admin querying. Best-effort update post-sign-up.

## Status / caveats

- All three are **working templates** — DPO details, retention periods, venue, fees, and legal citations are placeholders for KTC + counsel. Not legal advice. Confirm NPC registration obligations.
- Re-consent on a version bump is **not yet enforced** for existing brokers (future lane).
- Migrations `0011` + `0012` must be applied to the KTC DB for the columns to populate.

## Related

- [[Broker IRR]] · [[Brokers]] · [[Authentication]] · [[RLS Posture]]
- ADR-0008, ADR-0009
