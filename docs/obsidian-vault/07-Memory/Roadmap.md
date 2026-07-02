---
title: Roadmap
tags: [memory, roadmap, planning]
type: memory
last_updated: 2026-07-02
---

# 🧭 Roadmap (Phased)

**Authoritative sequencing for KTC work.** Ordered by what ships next. When a phase finishes, its items move to [[Completed Milestones]] and the next phase becomes *Now*.

Legend: **COMPLETED** · **NOW** · **NEXT** · **LATER** · **PARKED** · **NORTH STAR**.

> **Active focus (2026-06-22):** portal / job-orders. The **fuel-monitoring** module ([ADR-0025](../../adr/0025-fuel-monitoring-derived-variance-on-moves-spine.md)) was started as a parallel lane and is **parked after Phase 0** (schema live, no frontend) — see PARKED below.

> **Active focus (2026-07-01):** ADR-0037 cutover is live; the charges/payment-orders spine is the operational money path. v2.0.11 added the internal Android staff-app lane, and July 1 go-live hardening shipped through `0236` (bulletin archive, tariff images, email-change flow, trusted MFA sessions, route/menu transition hardening, Lara avatar/chat, CIS print, request tracking). Next work is **ST08 execution**, not another cutover: run the new July 1 rows first, then all-roles/all-lanes plus Android Part 15, finish owner/business checklist items, then launch.

## COMPLETED ✅ (through v1.1.0, 2026-06-13)

- Schema + 2,488-consignee import; customer + admin portals; onboarding + approval; owner failsafe + invite-only staff.
- Vercel deploy + `portal.ktcterminal.com`; Turnstile CAPTCHA (server-enforced); full email (Resend).
- Admin job-order processing + serving numbers + checker station + admin file-on-behalf; printable A6 slip.
- Payments (manual proof + review) + calculator + ERP invoice recording (PAID/BILLED); admin-configurable rates/fees + data-driven service catalogue.
- Roles & security: cashier/checker + role matrix, TOTP 2FA, single session, idle timeouts, auto-suspend + watchdog, CSP/headers, ID retention.
- Per-role manuals + tours; version provenance; layered docs system + Playwright (16/16).

## NOW - Go-live smoke + internal Android device check

1. **Run `docs/smoke-test-08-go-live.md`** end to end: start with the July 1 hardening rows, then public/customer/staff/RBAC/money invariants plus **Part 15 Android internal app** on a real device. The sandbox APK already builds; device camera/offline-sync/local-notification behavior still needs physical validation.
2. **Operational onboarding** - staff/broker test accounts, DEA/service rates, bank/GCash/QR payment details, and owner side-by-side smoke.
3. **ADR-0037 cutover done** - charges/payment-orders live; old billing path retired; v2.0.7-v2.0.11+ hardening layered on top.

## NEXT — Launch gate (owner checklist: `docs/go-live-todo.md`)

1. **Native cloud push activation** - regenerate a valid Supabase `sbp_` PAT, deploy `send-native-push`, then set Firebase service-account secrets plus `native_push_url`/`native_push_secret` in Vault. Until then, native cloud push is configuration-pending, not a smoke failure.
2. **Counsel sign-off on Customer Agreement v4** (final PH pass; NPC registration; DPO mailbox; liability cap). Server-side consent enforcement is already live (`0162`).
3. **Public launch** - remove the prod-testing restriction after smoke sign-off.

## LATER — Hardening & integrations

5. BOC Sheets mirror (blocked on Google service-account creds); bounded admin import if needed.
6. Implement the 4 Playwright mutation `fixme` lanes; wire Playwright into CI.
7. Per-customer accredited-consignee scoping; JO drafts + document attachments; status-change notifications.

## LATER — Customer access & adoption (post-go-live UX; owner brainstorm 2026-07-02)

Non-blocking next-phase wins to lower the barrier to using the portal and drive adoption. Grouped by effort. **The fast-path ideas must not weaken identity/accountability** (the anti-fraud spine).

### Staff login & session (from the 2026-07-02 owner ideas)
- **Biometric / PIN staff unlock (native app).** Replace username+password typing on shared gate devices with fingerprint/face unlock — or tap-your-name + a short PIN, or a badge QR. Identity stays EXPLICIT; the biometric/PIN authenticates. Pairs with the native app + trusted-device revoke (`0237`).
- **Remember-me on the native device.** Persist the staff session so they don't re-login constantly; gate re-open with biometric/PIN. Balanced by single-session, idle-logout, and the "forget this device" revoke (`0237`).
- ❌ **Rejected — password-only login (auto-identify by password).** A password *proves* identity, it doesn't *state* it: password-as-identifier causes collisions, forces unsafe searchable password storage, and destroys the who-did-what audit trail. Use the biometric/PIN path instead.

### Quick-action "checkout" — magic-link, registered customers
- **Quick-Pay magic link (start here).** Registered customer gets the "charge ready" email → taps a one-time, short-lived, single-purpose link → focused "pay this charge" page (amount + attach proof) → submit. No portal login; email is the identity; token is single-use + expiring + scoped; approved-customers only; action stays backend-enforced.
- **Quick-File magic link (second).** Same passwordless pattern for a focused filing form; heavier (consignee/entry/vessel/containers). Builds on Lara's draft→New-JO handoff.

### Ease of access — quick wins
- **Customer PWA install ("Add to Home Screen") + web push** — the responsive site as an app-like icon with push, no store. (Staff PWA exists; extend a customer install prompt.)
- **Passwordless magic-link sign-in** for customers generally (alongside the existing Google login) — kills "forgot password" friction.
- **Notify on the customer's channel** (SMS/Viber) with a deep "track / pay" link straight to the order.
- **"Re-file this order" (clone a past JO) + saved/favourite consignees** — brokers repeat similar orders; one tap to duplicate.
- **Public no-login rate calculator + vessel schedule** as a teaser / lead-gen.

### Ease of access — long term
- **Customer native app (Capacitor)** — push, camera doc-capture (snap the DO/BL), offline drafts, QR scan; the customer-facing counterpart to the staff app.
- **Real payment gateway** (GCash / card / bank API) — instant confirmation, no upload-proof-then-cashier-confirm; big UX + cashier-load win.
- **Multi-user company accounts** — a broker firm with several staff + roles under one customer (supersedes the parked per-customer accredited-consignee scoping in LATER above).
- **ERP auto-invoicing (Frappe)** — remove the manual invoice step deferred at cutover.
- **Programmatic API / EDI** for high-volume brokers.

### Promote / drive adoption — quick wins
- **QR posters at the office/terminal windows** — "Skip the queue, file online"; counter staff nudge walk-ins to register (physical → digital funnel).
- **Announce to the existing broker list** (email + SMS blast) that the portal is live.
- **Share-to-client buttons** (order status, rate estimate, printable slip).
- **First-run nudges** ("finish your first Job Order") on top of the existing tours/video.

### Promote / drive adoption — long term
- **Priority / fast-lane for online pre-payment** — a behavior lever: pre-paid-online orders served first.
- **Customer history / analytics dashboard** (volume, spend, past orders) for stickiness.
- **Referral / "invite your team."**

## PARKED ⏸️ — Fuel monitoring (Phase 0 done)

**Derived-variance fuel module** on the [[Yard Operations — Pillar 2 (Move Logger + Yard)|moves]] spine ([ADR-0025](../../adr/0025-fuel-monitoring-derived-variance-on-moves-spine.md)). **Phase 0 is live in prod + committed** (schema, ledgers, effective-dated rates, 7 derived views, `purchaser` role). **Resume when the portal lane gives way:** wire the role + 3 fuel permissions into the frontend, then build the `/admin/fuel` desk → mobile pump logger → estimate-from-live-moves → efficiency/anomaly. Detail in [[Pending Items]] + [[Fuel Monitoring (Yard Operations sub-module)]]. It also pulls **Pillar 2** (the yard move logger) forward, since the fuel estimate reads the same `moves`/`equipment` spine.

## NORTH STAR ⭐ — Terminal + Depot Operating System

The endgame: create/upgrade KTC's existing TOS into an **Octopi-class, modular Navis-style terminal + depot operating system**. The portal so far solved **ancillary-services queuing** (one module); the next foundation is the **container/EIR data spine**, then gate / depot-M&R / yard / billing / EDI.

- Vision: [[Terminal & Depot Operating System (North Star)]]
- Decision: **ADR-0015** · Grounded brief: `docs/research/navis-tos-landscape-2026-06-13.md`
- Gating question: what is KTC's *existing* TOS today (decides create-vs-upgrade)?

## Related

- [[Current State]] · [[Pending Items]] · [[Completed Milestones]] · [[Release Waves]] · [[Home]]
