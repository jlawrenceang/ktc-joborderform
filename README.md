# KTC Job Order System

Broker-facing portal for **KTC Container Terminal Corp.** — accredited brokers log in,
submit Job Orders (X-ray / DEA / OOG stripping) against their **approved consignees**, and
manage accreditation requests.

**Stack:** Vite + React + TypeScript + Tailwind + Supabase (Auth + Postgres + RLS).
**Hosting:** Vercel (free Hobby for testing). **Design:** JTA v2 "visionOS" tokens, KTC accent.

## Why an app (not just the Jotform)

We started on Jotform (see [`docs/`](docs/)) and it's kept as a **working fallback form**.
But "show each broker only *their* accredited consignees, behind a real login" needs a
database + auth — which Jotform can't do natively. That's this app.

## Getting started

```bash
npm install
cp .env.example .env.local   # fill from your KTC Supabase project (Settings -> API)
npm run dev
```

### Supabase setup (one time)

1. Create a **KTC-exclusive Supabase project** (separate free account).
2. SQL Editor → paste [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql) → Run.
3. Copy the project URL + anon/publishable key into `.env.local`.

## Data model

| Table | Purpose |
|---|---|
| `consignees` | master list (code, name) — uploaded later |
| `brokers` | broker profile, 1:1 with an auth user |
| `accreditations` | broker ⇄ consignee links (pending/approved/rejected) |
| `job_orders` | a submission (auto `X-#####`, broker, entry #) |
| `job_order_lines` | the repeating container rows (number + service) |

RLS ensures each broker only sees their own data. The per-broker consignee dropdown is just
`accreditations` filtered to `status = 'approved'`.

## Layout

```
src/
  lib/        supabase client + AuthContext
  pages/      Login, Home (Job Order / Accreditation UIs next)
  components/ ProtectedRoute
  styles/     v2-tokens.css (visionOS design tokens)
supabase/migrations/  schema
assets/, scripts/, docs/   the original Jotform form + its theme (fallback)
```

## Status / next

- [x] App scaffold, auth (Supabase), branded login + home shell
- [x] Schema + RLS migration
- [ ] Consignees uploader (Excel → `consignees`)
- [ ] Accreditation request + admin approval
- [ ] Job Order form with per-broker approved-consignee dropdown
- [ ] Deploy to Vercel
