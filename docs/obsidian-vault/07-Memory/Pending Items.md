---
title: Pending Items
tags: [memory, pending, backlog]
type: memory
last_updated: 2026-06-07
---

# 📋 Pending Items

Detailed backlog. For sequencing, see [[Roadmap]].

## Prod-testing readiness (NOW)

- [ ] Execute **ST01 browser lanes** (`docs/smoke-test-01-portal.md`, lanes 1–5) on `portal.ktcterminal.com`. Preflight P1–P7 already PASS (2026-06-07); lanes 1–5 need a manual walk.
- [ ] Supabase Auth → URL Configuration: Site URL `https://portal.ktcterminal.com`; add Redirect URL `https://portal.ktcterminal.com/**`.

## Apply migrations

- [ ] **Apply `0011_broker_irr_acceptance.sql` and `0012_broker_consents.sql`** to the KTC DB (`node scripts/run-migrations.mjs` with `DATABASE_URL`, or the SQL Editor) so the broker IRR/Terms/Privacy consent columns exist. Consents are recorded in auth metadata until then.

## Legal docs / consents (NEXT)

- [ ] KTC + counsel to finalize the templates: `broker-irr.md`, `terms-and-conditions.md`, `privacy-notice.md` — fees, penalties, dates, **DPO contact**, retention periods, venue, legal citations. Confirm **NPC registration** obligations. Bump the relevant `*_VERSION` on material change.
- [ ] Enforce re-acceptance / re-consent when a `*_VERSION` changes for already-registered brokers (compare stored vs current on login).
- [ ] Surface IRR/Terms/Privacy consent version + timestamp in the admin Brokers/Approvals view.

## Admin / processing (NEXT)

- [ ] `/admin/job-orders` — status workflow + decisions (process/complete/reject).
- [ ] `/admin` dashboard — live metrics (pending brokers, pending consignees, open job orders).
- [ ] Per-broker accredited-consignee scoping — restrict job-order targets to a broker's accredited consignees.

## Go-live hardening (LATER)

- [ ] Resend SMTP — broker email confirmation + password reset. Needs SPF/DKIM/MX on `ktcterminal.com` and Supabase SMTP config.
- [x] Automated smoke tests — Playwright Phase 1 (`e2e/smoke.spec.ts`, 10 tests) passing vs the deployed URL.
- [ ] **Playwright Phase 2** (authenticated flows, ST01 Lanes 2–5) — decide the CAPTCHA-free auth path: (A) dedicated test Supabase project with CAPTCHA off / Turnstile test keys, or (B) service-role session minting in CI. Then implement per-role storageState fixtures. See `e2e/authenticated.spec.ts`.
- [ ] Wire Phase 1 Playwright into CI (GitHub Actions) once a workflow exists.
- [ ] Process the 2,488 imported consignees through accreditation over time.
- [ ] Public launch (remove access restriction).

## Ops notes

- Turnstile secret rotated; lives only in Supabase. Site key in Vercel env (`VITE_TURNSTILE_SITE_KEY`).
- Changing a Vercel env var requires a redeploy.

## Related

- [[Roadmap]] · [[Current State]] · [[Home]]
