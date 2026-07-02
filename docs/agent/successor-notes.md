# Successor notes — continuation state for the next agent (written 2026-07-02)

For any agent (or model generation) picking this repo up. The **methodology is owned by the global
layer** (`~/.claude`: the engineering bible, the Loop, the 15-station go-live production line, the
`jarvis` verify beat) — this file carries only what is repo-specific: what's proven, what's pending,
and in what order. Don't restate the global rules here; they're loaded every session.

## Trust map — verified, lean on it
- **Release gate** (`docs/agent/release-gate.md`, 6 checks) + `scripts/check-security-invariants.mjs` + pre-commit hook (`.githooks/` — secret scan + constitution cap; per-clone wiring: `git config core.hooksPath .githooks`).
- **Break-test closed 2026-07-02** (`docs/audits/2026-07-02-sandbox-breaktest.md`, migrations 0240–0243); prelaunch battery **184/184** read-only e2e; a11y ≥90; load 2000 req/50conc p95 584ms 0 err; blind walkthrough done 2026-07-01.
- **Money spine SOUND** (8 billing invariants; double-collection fixed at 0239) — but red-zone changes still get `jarvis` + derived-expected-values, never trust-the-test.
- `docs/architecture-overview.md` stamped 2026-07-02 — fresh at time of writing; re-verify the stamp before trusting it.

## The go-live punch list (ordered — finish the line before launch)
1. **Mutating e2e lane** (sandbox) — the read-only battery is done; the authenticated/mutating lane is the pending half (`docs/audits/2026-07-02-prelaunch-battery.md`).
2. **Fresh roast** — the only roast artifact is 2026-06-28 (pre-hardening). Re-run post-seed; the bar is **90/100** (global rule), below = fix and re-run.
3. **ST08 side-by-side run** (`docs/smoke-test-08-go-live.md`) — script exists, the RUN is pending; re-scope it through the current migration head when run (it was written against 0236; head was 0243 at time of writing).
4. **Go/no-go decision doc** — none exists; write it at decision time: rollback rehearsed, abort signal named, no-go-is-a-normal-outcome. Owner items feeding it: `docs/go-live-todo.md` (NPC registration, counsel pass, per-staff 2FA enrollment).
5. **Watch-window / hypercare artifact** — zero artifact today; define before launch: window length, who watches which dashboard, and the andon rule (a field defect re-enters the line at Station 0, never patched blind).

## Scaffold completions (armed, in priority order after go-live)
- **Eval mini-set** (`evals/`, 3–5 golden cases on the red zone): charge math, `consignees_public` RLS matrix, release double-collection regression (0239's class). Prereq: the framework runner needs its cwd-fallback first (global playbook Y4.2 owns the method).
- **Quarterly `jarvis` recall calibration** (seed 2–3 known bugs in a scratch diff; log catch-rate) — and before Station 2 of any go-live.
- **Scorecard habit**: one row per ship in `docs/scorecard.md` (seeded 2026-07-02, empty by design).
- **Domain features from the SCM map** (`docs/agent/domain-scm-knowledge.md`): owner-priority — landed-cost calculator upgrade, concentration alerts, shared vessel-schedule workspace are the three with the clearest client value.

## Repo-specific operating notes
- The constitution (`CLAUDE.md`) is deliberately ≤150 words — five Non-negotiables + the release gate. The 200-word hard cap is now machine-enforced by the pre-commit hook; if it blocks you, move detail into `docs/agent/*`, don't override.
- `mcp__supabase__*` tools point at the OTHER client (jta-sys) — the runtime-data-safety rule exists because of this exact trap.
- Promotion hygiene: anything learned here that's worth globalizing must pass `docs/agent/denylist.txt` (grep before promoting — client identity and schema words stay here).
- History is in `docs/obsidian-vault/06-Sessions/` + `CHANGELOG.md`; current truth is `07-Memory/Current State.md`; when they disagree with code, code wins and the doc gets fixed in the same change.
