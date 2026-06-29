---
title: 2026-06-29 Phase-5 Verification, v1.7.0–v1.7.5, MFA Gate, ADR-0037 Move-Spine
tags: [session, security, ux, architecture, mfa]
date: 2026-06-29
---

# 2026-06-29 — Phase-5 verification, v1.7.0→v1.7.5, MFA gate, ADR-0037 move-spine

A very long session: shipped the unmerged audit-remediation Phases 2–4, then ran a full **Phase-5 verification loop** (the [[break-testing]] order-of-operations — static review → e2e → visual roast → security audit → batch-fix → re-verify), hardened MFA, and **co-designed + ratified [[ADR-0037]]** — the move-spine architecture that becomes the foundation of the north-star ([[ADR-0015]]).

## The ships (v1.7.0 → v1.7.5)

- **v1.7.0** — merged the unshipped audit-remediation **Phases 2–4** to main (the ops gaps, manuals/tours, full **Tagalog i18n** + a strict i18n-coverage guard), plus two **dormant scaffolds**: the **SMS** notification path (`0193`, `send-sms`) and the **BOC customs Sheet mirror** (re-scoped to X-ray inspection) — both awaiting owner activation creds.
- **v1.7.1** — hotfix of 2 live bugs the ship-review found: a **release-supplement money gap** (pay/confirm on a cancelled release) and the **AppChecker/Checker submitted-order dead-end** (`0194`). jarvis caught the desktop twin.
- **v1.7.2** — the **Phase-5 UX/UI batch** (13 **error-blind data loaders** → error+Retry, the read-side of "green tests, dead app"; Approvals false-"ID removed" claim; JO-filing confirmation; Brokers search+pagination; shared **Modal** + **Notice** a11y; de-glassed Home tiles; Lara FAB hides on input focus; semantic-token aliases; a new **offline banner**) + the **e2e 8-config recalibration** (the smoke "14/14 fail" was a `BASE_URL=localhost` footgun, **not** stale selectors; new viewport×locale×theme matrix + a `layout.spec` overflow guard) + `0195` (release-trigger ACL).
- **v1.7.3** — the **security-audit remediation** (`0196`–`0201`): disposable-email-table RLS lockdown, `cancel_release_order` base-payment guard, the **crown-jewel-RPC aal2-hardening** (`reset_staff_password`/`promote_new_staff`/`set_owner_access` now gate on hardened `is_owner()` — *the owner→staff-minting prevention*), JO `submit_supplement_proof` guard, staff-notif session gate, and the invoice-before-confirm trigger (base only). Plus the **Hybrid admin layout** (dense full-width ops console ≥1280px; mobile/tablet keep the app-like column) and the Suspend button retoned to true danger-red.
- **v1.7.4** — the **MFA challenge now renders before** the first-run setup modal.
- **v1.7.5** — a top-level **MfaGate** so the MFA challenge **encompasses the whole app** (App-root overlays no longer leak at aal1) + **ADR-0037** committed and ratified.

## Verification (the Phase-5 loop)
- **Ship-review** (ultracode) → 2 live bugs (fixed v1.7.1) + lows.
- **e2e** — the customer happy+break lane proved the wires alive + abuse blocked; recalibrated to the 8-config matrix (desktop/mobile × EN/FIL × light/dark) with an overflow guard (40/40 green; no Tagalog/dark/mobile breaks).
- **Visual roast** (new tools) — customer **84/100** (de-glass landed), admin **75/100** (consumer-chrome density → the Hybrid layout). One false-positive caught + rejected (a "Home photo" that doesn't exist).
- **Security audit** (ultracode, 5-dimension fan-out + adversarial verify) — **7 confirmed of 15** (8 false-positives refuted); 4 medium / 3 low, none critical/high. Fixed in `0196`–`0201`.
- **jarvis** earned its keep — caught **4 real blockers** before prod: the Modal focus-steal (consignee form untypable), the `0201` RPS-confirm break, the Hybrid-layout customer-nav leak, and the owner-lockout question on the aal2-hardening.

## MFA hardening
The owner enrolled TOTP + rotated the owner password. Three fixes: MFA-before-setup (v1.7.4), the whole-app MfaGate (v1.7.5), and the confirmed behaviour that a wrong code lets you **retry** (not kick out). **Note:** Supabase TOTP has **no native backup codes** — recovery is currently server-side factor-deletion; proper backup/recovery codes are carry-over. The staged A2 (mandatory-enrollment gate) + B (step-up re-auth) + C (out-of-band alert) were deliberately **deferred** (owner-lockout risk; the DB-side aal2 prevention is already live).

## ADR-0037 — the architecture (ratified)
Co-designed with the owner: **every operational move = its own Job Order**; **JO : ERP invoice : BIR invoice = 1:1:1** (draft→final; payment only against the final); **Payment Order : JO = 1-to-many** (the cashier bundles whole JOs; never split a JO; payment-orders ≤ JOs); **payment-before-movement** enforced bidirectionally at gate-in + gate-out; **supplements retired** (an add-on is a linked additional JO, reusing `parent_job_order_id`). Pre-launch (no real customer data) → a **clean reshape**, not a delicate migration. Phasing **A→B→C→D**; **Phase A** (payment_orders + per-JO ERP+BIR invoice + cashier gate) is the go-live compliance build. See [[target-architecture-jo-payment-invoice]] (memory) + ADR-0037.

## Carry-over (next session)
Phase A of ADR-0037 (open: fold B into A vs A-then-B) · the staged MFA work (A2/B/C + backup codes) · audit-low #5 consignee-PII scoping · the full **sandbox break-test** (params in `sandbox-breaktest-params.md`) · the **test-environment** setup (Supabase branch or test project) · the **domain consolidation** (ktcport.com WordPress + erp.ktcport.com Frappe + ktcterminal.com — the WP site is real; old `ktcbbernal` app-password revoked this session) · go-live checklist (NPC reg, Agreement-v4 counsel sign-off, Google-OAuth config, payment details still blank).

## Links
[[Current State]] · [[System Scale]] · [[Roadmap]] · [[Pending Items]] · [[Open Decisions]] · [[Job Order Lifecycle]] · [[Authentication]] · ADR-0037 · ADR-0015
