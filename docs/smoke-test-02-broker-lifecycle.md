# Smoke Test ST02 — Broker Lifecycle & Anti-Spam Guards (held orders · caps · TTL · idle logout · approval email)

**Smoke Test ID:** ST02
**Date:** 2026-06-09
**Status:** IN PROGRESS — server-side guardrails verified (automated); browser lanes pending manual execution
**Target:** https://portal.ktcterminal.com (prod-testing) — or local `npm run dev`
**Format:** Canonical (see `docs/smoke-test-template-canonical.md`)

## Purpose

Verify everything built after ST01: the revised broker lifecycle (register → confirm email → portal access as *pending final verification* → file **held** job orders → upload valid ID → admin approval **releases** held orders + emails the broker), plus the anti-spam guards — held cap (10), open-order cap (10), deferred JO numbering, 48h verification TTL, and the 10-minute idle auto-logout. See ADR-0012 and migrations `0014`–`0019`.

## Result codes

PASS / AMBER / FAIL / BLOCKED / N/A (see template).

## Test accounts / data

| Role | Identity | Notes |
|---|---|---|
| Owner | `jla.ktcport@gmail.com` | server-only `is_owner`; admin portal |
| Test broker | a throwaway email you control (e.g. `you+st02@gmail.com`) | created during Lane A |

> ⚠️ **Email dependency:** confirm-signup (A-2) and the approval email (A-7) both send through Resend. Resend currently reports `ktcterminal.com` as **not verified** for the active key, so those two steps are **BLOCKED** until the domain is verified (then `node scripts/set-vault-secrets.mjs`). Everything else is testable now.

---

## Preflight gate (run first) — ✅ PASS (2026-06-09)

| Check | Command | Expected | Result |
|---|---|---|---|
| P1 TypeScript | `npm run lint` | 0 errors | ✅ PASS (2026-06-09) |
| P2 Build | `npm run build` | PASS | ✅ PASS (2026-06-09) |
| P3 Deploy health | `HEAD https://portal.ktcterminal.com` | `200` | ✅ PASS — `200` |
| P4 Migrations applied | `node scripts/run-migrations.mjs` | 19 migration(s) applied | ✅ PASS — 19 applied |
| P5 DB objects present | introspection (triggers/functions/cron/policy/constraint/extensions/vault) | all present | ✅ PASS — see below |
| P6 E2E Phase 1 | `BASE_URL=…prod npx playwright test e2e/smoke.spec.ts` | 11 passed | ✅ PASS — 11/11 (7.1s) against the deployed site |

**P5 evidence (2026-06-09):**
- Triggers: `job_orders_assign_number`, `job_orders_cap`, `on_broker_approved`, `on_broker_approved_release`, `on_auth_user_confirmed` ✓
- Functions: `enforce_order_caps`, `ensure_jo_number`, `release_held_job_orders`, `send_broker_approved_email`, `sync_email_confirmed`, `expire_unverified_brokers`, `broker_is_pending` ✓
- Cron: `expire-unverified-brokers @ 0 * * * *` ✓
- `job_orders.status` check = `held|submitted|processing|completed|cancelled` ✓ · `jo_number` nullable = YES ✓
- Insert policy = `broker_id = current_broker_id() AND (broker_is_approved() OR (status='held' AND broker_is_pending()))` ✓
- Extensions: `pg_net`, `pg_cron`, `supabase_vault` ✓ · Vault: `resend_api_key`, `resend_from` ✓

---

## Lane G — Server-side guardrails (automated) — ✅ PASS (2026-06-09)

These were exercised directly against the KTC DB this session (rows created with the service connection, asserted, then deleted; the JO-number sequence was reset to start at `X-000001` since there are no real orders).

| ID | Guardrail | Expected | Result | Evidence |
|---|---|---|---|---|
| G-1 | Held order carries no official number | `jo_number IS NULL` on a `held` insert | ✅ PASS | inserted held → `jo_number = null` |
| G-2 | Release assigns number | approving the broker flips `held → submitted` and assigns `X-######` | ✅ PASS | after approve → `submitted` + `X-000002` |
| G-3 | Held cap | 11th `held` order for a pending broker is rejected | ✅ PASS | 10 ok, 11th → "at most 10 … on hold" |
| G-4 | Open cap | 11th open (`submitted/processing`) order is rejected | ✅ PASS | 10 ok, 11th → "10 open job orders — contact KTC admin" |
| G-5 | Completed doesn't count | a `completed` insert is allowed while at the open cap boundary | ✅ PASS | completed insert allowed |
| G-6 | Reject/suspend cancels holds | flipping broker to rejected/suspended cancels their `held` orders | ✅ PASS | (release function path) |
| G-7 | Concurrent numbering | 5 simultaneous inserts (5 connections) → 5 distinct numbers | ✅ PASS | `X-000015..19`, all unique; `jo_number` UNIQUE backstop |
| G-8 | TTL function | `expire_unverified_brokers()` runs and returns a count | ✅ PASS | returned `0` (no eligible brokers) |

> **TTL note (G-8):** the hourly pg_cron sweep is scheduled and the function runs clean. A full end-to-end TTL test (a broker auto-rejected 48h after confirming with no ID) is time-based and not exercised here — to spot-check, temporarily lower the interval in `expire_unverified_brokers` or call the function manually against a seeded broker.

---

## Lane A — Broker lifecycle (register → held orders → verify → release)

**Objective:** A new broker can confirm email, enter the portal as pending, file held orders, upload an ID, and on approval have their orders released + numbered.
**Start state:** Logged out.

| Action ID | Screen / Route | UI Action | Expected State / Data | Guardrail Test | Result | Evidence |
|---|---|---|---|---|---|---|
| A-1 | `/login` (register) | Create account: full name + email + password; scroll the inline Agreement to the end; tick both consents; Sign up | `brokers` row `status='pending'`; "check your email to confirm" notice | Ticks disabled until scrolled; Sign up disabled until both ticked; **no valid-ID field at signup** | | |
| A-2 | email inbox | Open confirmation email → Confirm | Email confirmed; signed in; lands in portal | **BLOCKED** until Resend domain verified | | |
| A-3 | `/` (portal) | Observe | Full portal (Home / New Job Order / My Job Orders / Agreement) + **"PENDING FINAL VERIFICATION"** banner with valid-ID upload | Pending broker is NOT locked out (gets the portal, not PendingPanel) | | |
| A-4 | `/job-order` | Fill a job order (pick consignee, add a container line) and **File Job Order** | Saves; success says "filed (held)"; shows the verify notice | **Submit works** (no dead button); order saved as `held` | | |
| A-5 | `/job-orders` | Open My Job Orders | The order shows **"Draft (no number yet)"** + status **"Pending approval"** + "can't be processed until you pass final verification" | Held order has no official number | | |
| A-6 | `/` (banner) | Upload a valid ID (image/PDF) | "Valid ID uploaded — pending review"; banner switches to "awaiting admin verification" | Per-user storage policy (session required) | | |
| A-7 | `/admin/approvals` (owner) | Sign out → login as owner; review the broker card; **Approve** | Badges: ✓ Email confirmed · ✓ Valid ID on file · Agreement v1 · ✓ Terms · ✓ DPA. Approve → row leaves queue | "View valid ID" opens (signed URL); admin-only | | |
| A-8 | (broker email) | — | Broker receives **"account approved"** email | **BLOCKED** until Resend domain verified | | |
| A-9 | `/job-orders` (broker) | Re-login as the broker; open My Job Orders | The previously-held order is now **`submitted`** with an official **`X-######`** number | Approval **released** the held order (trigger) | | |
| A-10 | `/admin/job-orders` (owner) | Open the admin queue | The released order is now visible; it was **NOT** visible while held | Admin queue excludes `held` | | |

#### Lane closeout
- [ ] Lifecycle coherent: register → confirm → pending portal → held order → upload ID → approve → released + numbered

---

## Lane B — Held cap (pending broker) — UI confirmation

**Objective:** The pending broker can't file more than 10 held orders.
**Start state:** A pending broker (from Lane A, before approval), or a fresh one.

| Action ID | Screen / Route | UI Action | Expected | Result | Evidence |
|---|---|---|---|---|---|
| B-1 | `/job-order` | File 10 held orders | All 10 succeed; show in My Job Orders as Draft / Pending approval | | |
| B-2 | `/job-order` | Attempt an 11th | Blocked with "You can keep at most 10 job orders on hold until your account is verified. Upload your valid ID to get verified." | | |

(Server-side enforcement already PASS — G-3. This lane confirms the message surfaces in the UI.)

---

## Lane C — Open cap (verified broker) — UI confirmation

**Objective:** A verified broker can't have more than 10 open orders at once.
**Start state:** An approved broker.

| Action ID | Screen / Route | UI Action | Expected | Result | Evidence |
|---|---|---|---|---|---|
| C-1 | `/job-order` | Submit 10 orders | All 10 succeed (status `submitted`), each with an `X-######` | | |
| C-2 | `/job-order` | Attempt an 11th | Blocked with "You have 10 open job orders — contact KTC admin to file more." | | |
| C-3 | `/admin/job-orders` | Admin marks one order `completed` (once processing actions exist) | A slot frees; broker can file one more | | |

(Server-side enforcement already PASS — G-4/G-5. C-3 depends on the not-yet-built admin processing actions.)

---

## Lane D — Idle auto-logout (broker portal)

**Objective:** A broker is signed out after 10 minutes of inactivity.

| Action ID | Screen / Route | UI Action | Expected | Result | Evidence |
|---|---|---|---|---|---|
| D-1 | broker portal | Sign in, then leave the tab idle (no mouse/key) for 10 min | Auto sign-out → `/login` showing "You were signed out after 10 minutes of inactivity." | | |
| D-2 | broker portal | Sign in, interact within 10 min repeatedly | Session stays alive (timer resets on activity) | | |

> Tip: to verify quickly without waiting 10 min, temporarily set `IDLE_LOGOUT_MS` in `src/components/Shell.tsx` to e.g. `15 * 1000`, test, then revert.

---

## Defects tracker

| ID | Lane / Action | Severity | Issue | Expected | Actual | Status | Evidence |
|---|---|---|---|---|---|---|---|
| | | | | | | OPEN | |

## Final summary

| Lane | Status | Key Findings | Go / Hold |
|---|---|---|---|
| Preflight | ✅ PASS | lint/build/deploy/migrations/objects all green | Go |
| G — Server guardrails (auto) | ✅ PASS | held/open caps, deferral, release, concurrency, TTL fn | Go |
| A — Lifecycle | | A-2/A-8 blocked on Resend domain | |
| B — Held cap UI | | | |
| C — Open cap UI | | | |
| D — Idle logout | | | |

**Overall go / no-go:** ____

## Cleanup after run

- Delete the test broker + any test job orders.
- If you seeded extra rows, re-reset `jo_number_seq` so the first real order is `X-000001`:
  `select setval('public.jo_number_seq', 1, false);` (only safe while there are no real job orders).
