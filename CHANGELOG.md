# Changelog

All notable changes to the KTC broker portal. Newest first. Dates are absolute (YYYY-MM-DD).

## [Unreleased]

### 2026-06-09
- **Broker IRR (ADR-0008):** added the Implementing Rules and Regulations. Content in `src/content/broker-irr.md` (`IRR_VERSION` in `src/content/irr.ts`); public `/irr` page (`src/pages/Irr.tsx`, built-in Markdown renderer) + broker-nav link. Registration now requires a "I agree to the IRR (v1)" checkbox; acceptance recorded in auth metadata (always) and on `brokers` columns via migration `0011`. Added 2 Playwright tests (IRR page public; signup requires acceptance) — 10 Phase 1 tests now. **`0011_broker_irr_acceptance.sql` must be applied to the KTC DB.**
- **Flow change (ADR-0007):** disabled per-broker consignee accreditation. The New Job Order page now searches the full consignee master list (debounced server-side typeahead) instead of an accreditation-fed dropdown; any approved broker can pick any consignee. Removed the Accreditation nav link; `/accreditation` now shows a notice (route kept). `accreditations` table + admin features untouched (reversible).
- Added Playwright E2E (`e2e/`, `playwright.config.ts`, `test:e2e` scripts). Phase 1 `smoke.spec.ts` (8 tests) — unauthenticated smoke against the deployed site (routing, login render, protected-route redirects, SPA rewrite, Turnstile mounts + submit gated); all passing. Phase 2 `authenticated.spec.ts` (5 `test.fixme`) — ST01 Lanes 2–5, blocked on a CAPTCHA-free auth path (documented in-file).

### 2026-06-08
- Added the canonical smoke-test template (`docs/smoke-test-template-canonical.md`) and ST01 portal smoke test (`docs/smoke-test-01-portal.md`) covering auth/CAPTCHA, broker onboarding, consignees/accreditation, job orders, and owner-only staff. Preflight P1–P7 verified PASS; lanes 1–5 are manual.

### 2026-06-07
- Added the layered documentation system mirroring jta-sys: `CLAUDE.md` constitution, `AGENTS.md` Codex mirror, `docs/agent/*` modular instruction reference, `docs/adr/` ADR system (template + index + foundational ADRs 0001–0006), `/adr` command, and the `docs/obsidian-vault/` live-memory vault (01-System / 02-Cores / 04-Workflows / 05-Concepts / 06-Sessions / 07-Memory / 09-Future).
- Added Cloudflare Turnstile CAPTCHA to login + registration (`src/components/Turnstile.tsx`), enforced server-side in Supabase Auth. Gated behind `VITE_TURNSTILE_SITE_KEY`.
- Deployed to Vercel with custom domain `portal.ktcterminal.com` (DNS on Vercel). Added `vercel.json` (Vite preset + SPA rewrite).

### 2026-06-05
- Owner-only staff creation (username + password, no email) via `rpc('create_staff')` in admin Settings.
- Consignee accreditation details (address, TIN, 2303 document) + approval workflow + pagination + search/edit/delete/validation/duplicate guard.
- Initial schema: migrations `0001_init` … `0010_create_staff`. Imported 2,488 consignees from `Customer.csv`.

---

Format: keep an `[Unreleased]` section at the top; add a one-line entry per meaningful change under the session date. See `docs/agent/doc-governance.md`.
