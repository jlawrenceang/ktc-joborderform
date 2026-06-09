# ADR-0010: Test authenticated flows via an isolated project + service-role session minting

* Status: Accepted
* Deciders: KTC project stakeholders (owner)
* Date: 2026-06-09
* Category: Workflow | Security

## Context and Problem Statement

Phase 1 Playwright covers everything reachable without logging in. The authenticated flows (owner→admin, broker job orders, consignee admin, staff) can't be automated against prod because (a) Supabase enforces CAPTCHA on every UI sign-in, and (b) the flows mutate data. How do we automate authenticated E2E without weakening prod's CAPTCHA or polluting prod data?

## Decision Drivers

* Never disable or weaken the production CAPTCHA to run tests.
* Never mutate production data from a test run.
* Reuse existing tooling (`@supabase/supabase-js`, Playwright); no heavy infra.
* Tests should skip cleanly when not configured, so CI/local stays green by default.

## Considered Options

* **Option A** — A dedicated **test Supabase project** (CAPTCHA off or Turnstile test keys) with a test build, pointed at by `BASE_URL`. Isolated data; UI login works.
* **Option B** — **Service-role session minting**: use the `service_role` key to generate a magic link (admin API, not CAPTCHA-gated), follow it in the browser to establish a session, then drive the UI — no UI password login, so no CAPTCHA.
* **Option C** — Temporarily disable CAPTCHA in Supabase for test runs.

## Decision Outcome

Chosen: **A + B together**. The auth harness (`e2e/helpers/session.ts`) implements **Option B** — `mintSession(page, email)` mints a session via service-role magic link regardless of project. It is pointed at whichever project the env names: a **dedicated test project for the mutation lanes (Option A)**, or prod read-only for non-mutating checks. `e2e/authenticated.spec.ts` runs the role-landing + read-only surface tests when `E2E_SUPABASE_URL` + `E2E_SERVICE_ROLE_KEY` are set, and **skips cleanly otherwise**. Mutation-heavy ST01 lanes are `test.fixme` until pointed at a seeded test project. **Option C was rejected** — never weaken prod protection for tests.

### Positive Consequences

* CAPTCHA stays fully enforced in prod; tests never disable it.
* The same minting harness works for a test project or prod; choosing is an env change.
* Tests skip by default — no secrets, no failures — and activate when configured.

### Negative Consequences / Trade-offs

* Requires the `service_role` key as a local/CI secret (never committed).
* Option A needs a second Supabase project + seed data (the KTC account has a free slot).
* Magic-link `redirectTo` (the `BASE_URL`) must be in the project's allowed redirect URLs.

## Pros and Cons of Options

### Option A: dedicated test project

* Good, because isolated data; full UI login works (captcha off); safe mutations.
* Bad, because a second project + seeding to maintain.

### Option B: service-role minting

* Good, because no UI login → no CAPTCHA; works against any project; minimal infra.
* Bad, because needs the service_role secret; mutating tests still shouldn't hit prod.

### Option C: disable prod CAPTCHA for tests

* Bad, because it weakens production bot protection — unacceptable.

## Related ADRs

* Extends [ADR-0006](0006-host-on-vercel-with-turnstile-captcha.md) (CAPTCHA enforcement) — this is how we test around it without weakening it.

## References

* `e2e/helpers/session.ts` · `e2e/authenticated.spec.ts` · `e2e/README.md`
* `playwright.config.ts`
