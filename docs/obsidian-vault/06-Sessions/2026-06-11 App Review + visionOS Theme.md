---
title: 2026-06-11 App Review + visionOS Theme
tags: [session, review, security, frontend]
type: session
date: 2026-06-11
---

# 2026-06-11 — Full app review (flow + security + UI) + visionOS theme layer

Two-track review (backend/RLS sweep + frontend flow/UX sweep) of the whole portal, plus fixes and a design-system upgrade shipped in the same session.

## Shipped this session

1. **visionOS theme layer v2** — extended `src/styles/v2-tokens.css` (material tiers, spring-motion tokens, semantic status tones) + `src/index.css` (ambient aurora canvas, global `:focus-visible` ring, `ktc-card` hover physics, `ktc-glass-thin/-thick`, `ktc-btn-secondary`, `ktc-btn--sm`, `ktc-chip--*` status pills, `ktc-skeleton` shimmer). Applied to Home cards, admin Dashboard tiles, Shell/AdminShell back pills, and My Job Orders (chips, skeleton loading, print-slip button). Reduced-motion + print-safe. Doc updated: [[visionOS Design System]].
2. **Migration `0031_order_cap_race_fix`** (applied) — `enforce_order_caps` now takes a per-customer `pg_advisory_xact_lock` before counting, closing the count-then-insert race that let concurrent inserts exceed the 10-order caps. Only substantive backend finding.
3. **Double-submit guard** — `JobOrder.tsx` ref-guards `onSubmit` (state `busy` is async, a rapid double-click could file twice).
4. **Approvals: ID-deletion failure surfaced** — if the DPA storage deletion fails on approve/suspend, the admin now sees a warning ("still on file — retry") instead of a false "ID was removed" message.

## Shipped (continuation — all 5 security notes settled + dead-end cleanup)

5. **Auth policy tightened server-side** — password 8+ chars w/ letter+digit, email rate limit 30/h (`scripts/set-auth-security.mjs`, applied via Management API; `check-auth-rate-limits.mjs` audits). Client forms aligned via shared `src/lib/validation.ts`.
6. **Upload limits server-enforced** — migration `0032`: 10 MB + image/PDF MIME allowlist on `valid-ids` + `consignee-docs`; client pre-checks (`uploadIssue()`); `create_staff` now enforces the same password policy (it bypasses GoTrue).
7. **`seed-owner.sql` fixed** — still pointed at pre-rename `public.brokers`; now `customers` + service-role-only note. (Owner failsafe re-grant would have errored.)
8. **MarkdownDoc boundary documented** — trusted repo content only; no innerHTML, no XSS.
9. **Accreditation dead ends removed** — `/accreditation` page+route, admin "Accreditation approvals" section, dashboard tile, unused type. DB table untouched. Deletion noted in **ADR-0007 addendum** (new practice: removals get an ADR note).
10. **Stale-status refresh** — `useBroker().refresh()`; ↻ buttons on the pending banner + My Job Orders.

## Shipped (continuation 2 — uploads v2, viewer, auto-poll, Harbor Glass)

11. **5 MB upload cap + image auto-compression** (migration `0033`, `prepareUpload`).
12. **In-app attachment viewer** — `FileViewerModal`/`useFileViewer` modal (Print + Save, blob-backed) replaces all new-tab signed-URL opens.
13. **Auto-poll** — `useAutoRefresh`: 60s visible-tab polling + 10s manual-refresh cooldown on My Job Orders + pending banner.
14. **Harbor Glass UI overhaul** — Schibsted Grotesk + IBM Plex Mono, frosted top nav (back-buttons/breadcrumbs removed), staggered reveal, typography classes swept, Home/Dashboard redesigned, admin code-split (main bundle 512→457 kB). E2E smoke un-staled (Customer Agreement wording) — 11/11 passing.

**Decisions this session:** status emails = lean set (action-required only) pending; P0 lifecycle build green-lit AFTER security loops (now closed); P2 cashier/ERP handoff **parked** for a dedicated audit discussion.

## Review verdict (summary)

- **Backend: strong.** RLS coverage on all sensitive tables verified; privilege escalation blocked (`guard_broker_protected_fields`); owner failsafe robust; storage per-user foldering correct; SECURITY DEFINER functions gated + `search_path` pinned. No critical/high findings. The cap race (fixed) was the only medium.
- **Frontend: good guards, some flow dead ends.** Print page relies on RLS for ownership (OK — returns no rows cross-customer). Login lockout is client-side only (cosmetic; Supabase server limits are the backstop). Key UX/flow gaps = the already-known lifecycle items: `on_hold` has no in-app customer response path, `rejected` is terminal, no edit/cancel, no status-change emails, stale UI after approval (no realtime/poll).

Full prioritized findings + recommendations were delivered in-session; flow gaps fold into [[Job Order Lifecycle]] open decisions (most were already tracked there).

## Related
- [[Current State]] · [[Job Order Lifecycle]] · [[visionOS Design System]] · [[Pending Items]]
- Migration `0031`
