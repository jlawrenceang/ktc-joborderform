# Pre-go-live app-test battery — 2026-07-02

**Scope:** the framework pre-launch app-test battery run against v2.0.12→v2.0.15 (migrations through `0239`), on an isolated sandbox (`zwvzadkgeyhkhyshkwhc`) brought current to prod + seeded. Order followed: cheap/broad/code-level → experience → load → sandbox last.

## Sandbox readiness (foundation)
- Sandbox was **6 migrations behind prod** (`0233`–`0238` never mirrored — the "0236 mirrored" note was inaccurate). Mirrored all six + `0239`; schema now matches prod.
- Seeded: owner (`jlawrenceang@gmail.com`), **7 test accounts** — `custa@sandbox.ktc.test` (approved, v4 consent), `custb@sandbox.ktc.test` (pending), and `admin/ops/cashier/checker/csr@ktc-staff.local` (staff roles), password `KtcSandbox2026!`; 1669 consignees from prod.
- Reusable load harness added: `scripts/loadtest-sandbox.mjs` (guarded, sandbox-only).

## Results by dimension

| Dimension | Result |
|---|---|
| **e2e** (read-only smoke + layout, 8 configs, live site) | ✅ **184/184** |
| **independent-verify** (Jarvis) | ✅ on 0237/0238/0239 + the review |
| **security** | ✅ opus review + Jarvis; no critical/high |
| **domain / billing-integrity** | ⚠️→✅ JO money spine **SOUND** (8 invariants hold); release seam **FIXED** (below) |
| **UX + accessibility** | ⚠️ **80/100** — punch-list OPEN (below) |
| **load** (sandbox read path) | ✅ 2000 req @ 50 concurrent, **0 err**, p50 327ms / p95 584ms / p99 1.6s |
| **regression** (kept flows) | ✅ folded into domain-integrity — register→approve→file→charges→PO→pay→complete + release desk intact |
| authenticated e2e (mutating) · roast · sandbox break-test · **ST08 side-by-side** | ⬜ pending (test accounts now seeded) |

## Findings

### HIGH — release double-collection seam — FIXED (v2.0.15, migration 0239)
The release/pull-out lane ran two unreconciled settlement paths: the authoritative release desk (`release_orders`) and a shadow `charge_type='release'` dual-write (0215) that was independently invoiceable/collectable in the cashier's Payment Order queue → the same release money could be collected twice (a second OR). **Fix:** a BEFORE-UPDATE guard trigger on `charges` (`0239`) blocks a release charge from being bundled / advanced to submitted-confirmed / invoice-finalized via the charge path (client-proof); frontend hides release charges from the cashier queue. Jarvis-verified SAFE-TO-APPLY; **prod reconciliation returned 0 non-pristine release charges — no historical double-collection.** JO money spine independently verified SOUND.

### MEDIUM/LOW — UX + accessibility punch-list (80/100) — 4 of 5 FIXED (v2.0.16), 1 deferred
Fixed in v2.0.16–v2.0.17: `<main>` landmark app-wide (`Shell`/`AdminShell`/`AppLayout`/`MarkdownDoc`/`ForgotPassword`), contrast (`--ink-2` + `--acc-2` link red + dropped the footer-stamp `opacity`), `ForgotPassword`→`<Notice>`, mobile tab-label ellipsis, docs i18n. **Re-scored (axe 4.10, WCAG 2.1 A/AA, public pages): `landmark-one-main` = 0, `color-contrast` = 0** (both previously-flagged categories clean → 80 → ≥90). **Residual:** one `scrollable-region-focusable` (LOW) on /register + the deferred admin `window.confirm()`→`Modal` (robustness, not a WCAG failure — native confirm is accessible; concern is Android-WebView flakiness). Original findings:
Real but narrow (axe-confirmed on public pages + code review):
1. **No `<main>` landmark** anywhere — one-line fix in `Shell.tsx:65` + `MarkdownDoc.tsx` (systemic).
2. **`--ink-2` contrast** fails on footer/version-stamp context (`v2-tokens.css:16`).
3. **Native `window.confirm()`** in `Consignees.tsx:239,289` (flaky in the Android WebView) — use the app `Modal`.
4. `ForgotPassword.tsx:89-98` notice divs lack `role="alert"` — use `<Notice>`.
5. Mobile tab-label overflow risk for longer Tagalog (`index.css:946`) — ellipsis/clamp.
Strengths: `Modal` focus-trap, `Notice` role-scoping, `MyJobOrders` loading/error/empty, text-labelled bottom nav.

### Load — PASS
Read path holds at 50 concurrent with 0 errors; ceiling remains GoTrue session-minting from a single IP (test-rig limit, not the app), consistent with the prior 500-concurrent result.

## Remaining before go-live
- Authenticated e2e (mutating lane) + **roast** — now unblocked by the seeded test accounts.
- **Sandbox break-test** (adversarial) → then the **ST08 side-by-side** (owner walks the identical critical paths; every path must agree).
- The a11y punch-list (top 5) — recommend fixing before public launch.
