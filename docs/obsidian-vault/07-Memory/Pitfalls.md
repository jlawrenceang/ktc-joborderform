---
title: Pitfalls
tags: [memory, pitfalls]
type: memory
last_updated: 2026-06-29
---

# ⚠️ Known Pitfalls (ktc-portal)

Repo-specific traps. Framework-level / operating traps live in `~/.claude/PITFALLS.md`. Append whenever something breaks (the `evals` close-the-loop routes here): the trap → the fix.

- **`broker` = `customer`.** Code/DB still say `broker` (`useBroker`, `BrokerStatus`, table history), but migration `0021` renamed the table to `customers` and the model is a single customer pool. Same actor — don't treat them as different (see [ADR-0028](../../adr/0028-rename-brokers-to-customers-single-pool.md)).
- **The connected `mcp__supabase__*` tools point at jta-sys, NOT KTC.** Never run them against this repo — KTC's runtime is `mdlnfhyylvapzdubhyic` via `src/lib/supabase.ts`. (Cross-account hazard.)
- **ADRs are `docs/adr/00NN-*.md`, not vault notes.** Link them with relative markdown (`../../adr/00NN-*.md`), never bare `[[ADR-NNNN]]` (doesn't resolve).
- **Don't hardcode migration/ADR counts in docs.** The `System Scale` ADR row drifted (said 0025, disk had 0027). Keep counts in [[Current State]] and link.
- **The aal2/MFA gate must sit ABOVE the router, not at the route level.** The MFA challenge originally lived inside `ProtectedRoute`, so App-root overlays rendered *beside* it (`FirstRunSetup`, `SessionSupersededOverlay`) and could show at aal1 (the bug the owner hit 2026-06-29). Fix: a top-level `MfaGate` in `App.tsx` that renders **only** `MfaChallenge` when a session is aal1-needing-aal2 — everything else is its child. Lesson: any whole-app auth/assurance gate belongs above `<Routes>`; anything rendered at the App root bypasses a route-level gate. (`MfaGate`, v1.7.5.)
- **`BASE_URL=localhost` in `.env.local` silently points the whole e2e suite at a dead port.** The smoke "14/14 fail" looked like stale selectors but was the Playwright `baseURL` resolving to `localhost:3000`. `playwright.config.ts` now ignores a localhost `BASE_URL` and resolves to the deployed site unless explicitly overridden. Check the target URL before debugging selectors.
