---
title: Home
tags: [index]
type: home
last_updated: 2026-06-29
---

# KTC Portal Knowledge Home

KTC Container Terminal Corp. — the **KTC Online Portal** for port / container-terminal operations. Accredited customers (customs brokers) submit Job Orders (X-Ray, DEA exam, OOG stripping) against consignees; KTC staff (owner + admin/operations/cashier/checker/csr) run a separate admin portal on an owner-tunable [[Staff Roles & Gates|permission matrix]].

## At a glance (update every session)

| Metric | Value |
|---|---|
| Version | `v1.7.5` live on `portal.ktcterminal.com` |
| Migrations | **~190 files** (`0001` … `0201`), all applied + tracked (split portal + fuel lanes) |
| Public face | signed-out `/` = a public **Landing** (terminal-photo hero); **Lara** non-LLM customer assistant; **"Continue with Google"** sign-in |
| Access hardening | pending customers **verify-only** at the RLS layer (`0163`); consent **server-enforced** (`0162`); disposable-email block (`0164`) |
| Staff roles | admin · operations · cashier · checker · csr (+ owner / root owner) — gated by `has_permission`. `purchaser` (fuel desk) exists in the DB but is **frontend-deferred** |
| Completion | **two-gate** — all services + base payment + RPS (if needed) + every supplement, all confirmed; derived "✓ Cleared for release" badge |
| Active focus | **Phase-5 verification + v1.7.0→v1.7.5 shipped** (2026-06-29): audit Phases 2–4 merged, UX/UI batch + 8-config e2e recalibration, **security-audit fixes `0196`–`0201`** (incl. owner→staff-minting prevention), **Hybrid admin layout**, and a **whole-app MfaGate**. **Next major work = [ADR-0037](../adr/0037-jo-as-atomic-move-payment-orders-1-1-1-invoicing.md)** *(Accepted)* — the move-spine architecture (every move = a JO; 1:1:1 ERP/BIR invoicing; Payment-Order N:1; payment-before-movement). Pre-launch clean reshape; **Phase A first**. Fuel monitoring still parked after Phase 0 |
| Go-live gate | `docs/go-live-todo.md` — **MFA now enrolled + owner password rotated** (2026-06-29); still: Google-OAuth config · Agreement v4 counsel pass + NPC/DPO · payment details (bank/GCash/QR) still blank · ADR-0037 **Phase A** (the BIR-invoice compliance build) · full sandbox break-test · ST05 manual Lanes A–K · launch call |
| Prod data | test data purged 2026-06-23 — first real order = `JO-000001` (0 orders / 0 customers / 0 releases) |

## Where the rules and memory live

KTC uses a layered documentation system:

- **Repo constitution** — `CLAUDE.md` + `AGENTS.md` (Codex mirror). Immutable top-level rules.
- **System map** — `docs/architecture-overview.md`: one-screen structural overview (topology, backend-enforced access model, the two spines, module/route map). Links out to live figures + detailed flows.
- **Modular instruction reference** — `docs/agent/*` (in the repo). Durable, path-retrievable detail: release gate, runtime data safety, workflow invariants, coding guardrails, testing, tooling, memory policy, doc governance.
- **Decision history** — `docs/adr/*`.
- **Live memory (this vault)** — current state, roadmap, pending items, per-core pages, sessions, milestones.

Rule of thumb: if you are asking *"what is the rule?"* open `docs/agent/*`. If you are asking *"what is live right now, what's next, what did we ship?"* open this vault.

## Start here

**New here?** Read [[Business Context]] first — who we are, who uses it, and what we're building (business background + product scope).

1. [[Current State]] — what is live right now (runtime-aligned snapshot)
2. [[Roadmap]] — phased plan (Now / Next / Later / Parked)
3. [[Pending Items]] — backlog
4. [[Completed Milestones]] — shipped history
5. [[System Scale]] — counts (migrations, consignees, routes)
6. [[Architecture]] — layer + domain map
7. [[Runtime Target]] — pointer to runtime-data-safety

## ⭐ North star

- [[Terminal & Depot Operating System (North Star)]] — the endgame: grow the portal into an Octopi-class **Navis-style terminal + depot operating system** (ADR-0015). The portal today solved ancillary-services queuing; the container/EIR data spine is the next foundation.

## Core modules

- [[Authentication]]
- [[Brokers]]
- [[Consignees]]
- [[Job Orders]]
- [[Administration]]

## Key concepts

- [[Staff Roles & Gates]] · [[Multi-Owner & Root Grants]] · [[Owner Failsafe]]
- [[Two-Gate Completion]] · [[Additional-Charge Supplements]] · [[Verify-QR Anti-Forgery]]
- [[Comment Visibility & Escalation]] · [[Cashier Station]] · [[Support Tickets]] · [[Staff Notifications]]
- [[CAPTCHA Bot Protection]] · [[RLS Posture]] · [[Broker Agreement]] · [[visionOS Design System]]
- [[Localization (i18n)]] · [[Mobile & Tablet UX]] · [[Lara (Customer Assistant)]]
- [[Job Order Lifecycle]] — full state machine (source of truth)

## Documentation governance

- Runtime code and migrations are source of truth.
- Rules live once — in `docs/agent/*`. The vault points, does not restate.
- Session notes are append-only under `06-Sessions/`.
