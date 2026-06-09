---
title: Broker IRR
tags: [concept, policy, brokers]
type: concept
---

# 📜 Broker IRR (Implementing Rules and Regulations)

The rules brokers agree to before transacting on the portal.

## Where it lives

- **Content (single source):** `src/content/broker-irr.md` — Markdown. Edit here to change the IRR text.
- **Version:** `src/content/irr.ts` → `IRR_VERSION` (e.g. `v1`) + `IRR_VERSION_LABEL`. Bump on material change.
- **Page:** `src/pages/Irr.tsx` at the **public** `/irr` route (readable before login; small built-in Markdown renderer, no dependency). Also linked in the broker nav.

## Acceptance gate

- Registration shows a **required** checkbox: "I have read and agree to the KTC Broker IRR (vN)" with a link to `/irr`. Sign-up is blocked until ticked (and CAPTCHA still applies).
- Acceptance is recorded:
  - **Auth user metadata** (`irr_version`, `irr_accepted_at`) at sign-up — always, even before the migration.
  - **`brokers` columns** (`irr_version`, `irr_accepted_at`) via migration `0011_broker_irr_acceptance.sql` — for admin querying. Best-effort update post-sign-up.

## Status / caveats

- The IRR text is a **working template** — fees, penalty schedules, dates, and legal citations are placeholders for KTC + counsel to finalize.
- Re-acceptance on version bump is **not yet enforced** for existing brokers (future lane).
- Migration `0011` must be applied to the KTC DB for the brokers columns to populate (acceptance still recorded in metadata until then).

## Related

- [[Brokers]] · [[Authentication]] · [[Broker Onboarding]]
- ADR-0008
