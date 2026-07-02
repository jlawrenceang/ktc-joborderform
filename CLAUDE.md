# CLAUDE.md

Constitution for the **KTC Online Portal** — KTC Container Terminal Corp. (container terminal / port services / depot). Context, scope, roadmap: `docs/obsidian-vault/01-System/Business Context.md`.

## Non-negotiables

- **Backend-enforced access.** Auth, approvals, roles live in RLS + SECURITY DEFINER RPCs, not the frontend. CAPTCHA server-enforced.
- **Runtime authority `src/lib/supabase.ts`** (prod `mdlnfhyylvapzdubhyic`). The connected `mcp__supabase__*` tools point at **jta-sys** — never use them here. See `docs/agent/runtime-data-safety.md`.
- **Owner failsafe.** `jlawrenceang@gmail.com` is the server-only owner — overrides everything, cannot be locked out. Staff invite-only; no self-signup.
- **Forward-only migrations.** `git push` deploys the frontend to Vercel, not DB changes.
- **Responsive web only.** No native mobile without an explicit ask.

## Release gate

Every plan, change, review, and merge passes the six checks in `docs/agent/release-gate.md`; failure blocks release.

Rules index: `docs/agent/README.md` · live memory: `docs/obsidian-vault/` · Codex mirror: `AGENTS.md`.
