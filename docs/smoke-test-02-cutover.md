# Smoke Test 02 — X-ray Billing Cutover (v2.0.0) · pre-go-live

**Purpose.** Verify the ADR-0037 charges-only cutover end-to-end before the public go-live.
Two parts: **(A)** an automated/agent **test battery** (run via the ultracode Workflow), then
**(B)** a **side-by-side smoke test** — the exact paths the agent walked, with my finding on each,
and a column for the **owner to walk the same path and confirm we agree**. Concurrence on every
critical path + a clean sandbox break-test = cleared for go-live.

**Sequence:** battery (1–8) → sandbox (final) → owner runs Part B blind, then manual, side-by-side → go live.

---

## Part A — The test battery (ultracode)

Order = cheap/broad/code-level first → experience → expensive/stateful last → sandbox final.

| # | Test | Scope | Method | PASS criteria | Status |
|---|------|-------|--------|---------------|--------|
| 1 | **e2e (automated)** | Customer lifecycle + smoke + auth + layout, on the live cutover | Playwright `npm run test:e2e` against `portal.ktcterminal.com` (specs updated for the charge flow) | All specs green; the file→charge→pay→complete lifecycle passes | ⬜ |
| 2 | **Jarvis (re-verify)** | Final v2.0.0 money/migration logic | Independent `jarvis` agent vs the acceptance criteria + read-only SQL | Verdict PASS (no gate bypass); any CONCERNS fixed | ⬜ |
| 3 | **Billing-integrity / anti-fraud** ⭐ | The 4 controls + the money invariants | Read-only SQL probes + transactional (BEGIN…ROLLBACK) attacks: confirm-without-ERP+BIR, complete-with-unpaid-charge, double/lost charge, reversed re-confirm, reconciliation math | Every invariant holds; no path to confirm/complete money improperly | ⬜ |
| 4 | **Security** | RLS / auth / ACL / injection | `check-security-invariants.mjs` + `check-auth-rate-limits.mjs` + an RLS/definer-ACL review of the new charge RPCs + consignee PII | Invariants green; no broker reads PII at scale; no definer trigger callable; no missing RLS on `charges`/`payment_orders` | ⬜ |
| 5 | **UX/UI + accessibility** ⭐ | The new charge screens, responsive + a11y | Drive desktop+mobile viewports; check the customer JobOrderCharges, PaymentOrderDesk, ChargeApproval, Reconciliation; keyboard/contrast/labels | Screens render correctly on phone+desktop; no broken layout from deleted screens; a11y has no critical violations | ⬜ |
| 6 | **Roast** | The live product vs the rubric | `roast` skill (authenticate, reach the real product), ≥90/100 bar | Scores ≥90; cited issues triaged | ⬜ |
| 7 | **Load** | Concurrency / perf | The load harness (per the 2026-06-16 hardening: 500 concurrent OK; GoTrue minting is the ceiling) against the cutover | No new bottleneck vs baseline; charges path holds under load | ⬜ |
| 8 | **Regression (kept flows)** | Release desk · rate calculator · auth/registration | Confirm the cutover didn't break what it kept | All kept flows work; calculator estimate == bill for billable services | ⬜ |
| — | **Sandbox break-test** | Full adversarial lifecycle on isolated data | break-testing skill on a SEPARATE KTC database (deferred — needs the project provisioned) | Catalogued → fixed → re-tested clean | ⬜ (final) |

*(Already green this session: i18n coverage, typecheck, production build.)*

---

## Part B — Side-by-side smoke test (owner replicates my paths)

For each path: **the exact steps I walked**, the **expected result**, **my result** (filled after I run it),
and an empty **owner column** — you walk the identical path and tick whether you see the same thing.
**Goal: every row "✅ agree."** Anything we don't agree on is a blocker.

> Legend — My result: ✅ pass · ⚠️ concern · ❌ fail (filled by me after the battery/sandbox). Owner: ☐ → ✅/❌.

### B1 · Customer files a job order → a charge appears (the core change)
1. Log in as an approved customer → **File a Job Order**.
2. Pick a consignee (type 2+ letters — the picker searches by code/name).
3. Add a container + service (X-Ray) → submit.
4. Open the order → the **Charges** section.

**Expected:** order files with a `JO-######`; the **Charges** panel shows an itemized **X-Ray** charge (qty × rate, VAT line, total); status "Unpaid"; no old "Pay" button/whole-order total.
**My result:** _[fill]_ · **Owner:** ☐

### B2 · Consignee privacy (anti-scrape)
1. In the consignee picker, type a 2-letter query.
2. (Technical) the picker calls `search_consignees`.

**Expected:** results show **only code + name** (no TIN/contact); you cannot pull the whole master list.
**My result:** _[fill]_ · **Owner:** ☐

### B3 · Admin processes + the invoice-before-confirm gate (anti-fraud)
1. As staff: open the order → **Accept** (processing).
2. Go to **Charges** (`/admin/charges`) → try to **confirm a payment without recording the ERP+BIR invoice**.
3. Record the **ERP + BIR** invoice on the charge → then confirm.

**Expected:** step 2 is **REFUSED** ("record the FINAL ERP + BIR invoice first"); step 3 succeeds. No charge can be confirmed without both invoice numbers.
**My result:** _[fill]_ · **Owner:** ☐

### B4 · Add-on is maker-checker
1. Staffer A adds an **add-on** charge to the order.
2. Staffer A tries to approve their own add-on.
3. Staffer B approves it.

**Expected:** the add-on is "Proposed · needs approval"; **self-approval is blocked**; a different staffer can approve.
**My result:** _[fill]_ · **Owner:** ☐

### B5 · Cashier collection via Payment Order
1. As cashier: **Payment Orders** (`/admin/payment-orders`) → bundle the order's billed charges.
2. Record the collection **OR** → confirm.

**Expected:** the charges bundle, each still needs its final invoice, the collection OR confirms them; the old `/admin/cashier` screen is gone.
**My result:** _[fill]_ · **Owner:** ☐

### B6 · One-rule completion
1. With all services X-rayed **and** every billed charge confirmed → the order auto-completes (or staff "Mark completed").
2. Try to complete an order that still has an unpaid billed charge.

**Expected:** completes only when services done **and** all charges paid; an unpaid charge **blocks** completion.
**My result:** _[fill]_ · **Owner:** ☐

### B7 · Customer pays a charge + the customer cancel rule
1. As the customer: on an unpaid charge, **upload a payment proof**.
2. Try to **cancel** the order *before* any billing moved → allowed.
3. Try to **cancel** *after* a charge has a proof/invoice/bundle → blocked ("contact admin").

**Expected:** per-charge proof upload works; cancel allowed while pristine, **blocked once billing is in flight**; admin can still cancel (with a reason).
**My result:** _[fill]_ · **Owner:** ☐

### B8 · Serving number format
1. View the X-ray queue / a filed order's serving tag.

**Expected:** the serving number reads **`YYMM-XXXX`** (e.g. `2606-0001`), resetting monthly — not `#N`.
**My result:** _[fill]_ · **Owner:** ☐

### B9 · Charge QR authenticity (anti-fraud)
1. Open a charge's verify QR / the public verify page → scan/visit it.

**Expected:** the public verify shows the **real** charge line items + amounts + paid state from the server (a forged/copied paper fails or reveals the true amount).
**My result:** _[fill]_ · **Owner:** ☐

### B10 · Kept flows didn't break
1. Open the **Rate Calculator** → build an estimate.
2. Open the **Release / pull-out** desk → file/charge a release.
3. **Register** a new test customer / log in.

**Expected:** calculator works (estimate matches the bill for billable services); the release desk works; auth/registration works.
**My result:** _[fill]_ · **Owner:** ☐

---

## Part C — Findings log (ultracode battery, 2026-06-29)

Battery verdict: **NOT go-live ready → remediated.** The **5 anti-fraud money gates all PASS** (confirm-needs-ERP+BIR, completion-needs-payment, re-seed money-safety, reversed-stays-terminal, reconciliation) and the kept flows (calculator, release desk, auth, record_van_xray) are healthy. The blockers were dropped-column orphans the `0220` discovery skipped (plain `payment_status`):

| Severity | Finding | Status |
|---|---|---|
| **CRITICAL** | `notify_jo_change` trigger read dropped `payment_status`/`payment_note` → every non-rexray job_order UPDATE errored (no transition/completion; cashier couldn't confirm the final charge) | ✅ FIXED `0223` + probed (transitions OK); deployed v2.0.1 |
| **HIGH** | `remind_unpaid_orders` cron read `job_orders.payment_status` | ✅ FIXED `0223` (charges-based) + probed |
| **HIGH** | `Home.tsx` dashboard + `BottomNav.tsx` badge `.or('…payment_status…')` on job_orders (400 / silent-0) | ✅ FIXED → `my_attention_count()` RPC; deployed v2.0.1 |
| **HIGH** | e2e never verifies the charge path — JO-wizard driver throws, baseCharge/chargeUi SKIPPED, gate only fails on /DEAD WIRE/ | ⬜ TODO (test-quality; app is fine) — task 19 |
| **HIGH** | Hero photos 404 (public/photos/[0-9]*.jpg are 289 MB, gitignored → not deployed) | ⬜ DEFERRED — web-optimize the ~8 used + commit, or CDN-host |
| MEDIUM | `ktc-chip--error` class undefined → rejected/cancelled chips render grey | ✅ FIXED (CSS alias); deployed v2.0.1 |
| MEDIUM | a11y: compliance inputs (ERP/BIR/OR/reason) + proof file input labelled by placeholder only | ⬜ TODO (quick aria-labels) |
| MEDIUM | roast: login submit looks disabled; register card grey/white seam (public ~74/100) | ⬜ TODO (polish) |
| LOW | NULL-amount charge can be invoiced/confirmed/complete at zero value (rate-config edge) | ⬜ consider blocking invoice/confirm on NULL/0 amount |
| LOW | `effective_rate` EXECUTE-able by authenticated (override-rate disclosure); admin desk seq-scans; CAPTCHA smoke skipped (localhost guard) | ⬜ review |

**Battery gaps (could not fully run — need provisioning):** `authenticated.spec` (a TEST Supabase project + creds); CAPTCHA/Turnstile gate; auth rate-limit (mgmt token); roast of the gated app + UX/a11y of the gated charge screens (customer + cashier creds + seeded data); a real load run (no harness + 0 prod data); the **data-isolated sandbox break-test** (separate KTC DB).

**Go-live gate:** Part A 1–8 pass · sandbox clean · Part B every row "agree" with the owner · Part C has no open high/critical. **Current: critical + high orphans fixed + deployed; remaining = e2e coverage + photos + a11y/roast polish + the gated-app/sandbox verification.**
