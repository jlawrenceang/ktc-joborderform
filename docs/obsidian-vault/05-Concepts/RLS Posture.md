---
title: RLS Posture
tags: [concept, security, rls, database]
type: concept
---

# 🔐 RLS Posture

How row-level security backs the role model.

## Model

- Every core table (`brokers`, `consignees`, `job_orders`, `job_order_lines`, `accreditations`) has RLS enabled.
- **Brokers** can read/write their own rows (scoped by `user_id`).
- **Admins/owner** can read all rows (broad admin policies) and perform privileged updates.
- Privileged actions that must not be client-forgeable (staff creation, role promotion) run through SECURITY DEFINER RPCs, not direct table writes.

## Pending → verify-only (the real wall, `0163`)

A customer with `status='pending'` (incl. any Google self-registration) is locked to **verify-only** at the RLS layer: they may only upload a valid ID, see their status, read the Agreement, manage account basics, and sign out. **Every business surface** — filing (`file_job_order` is approved-only), the vessel schedule, the rate/calculator config (`terminal_rates` / `service_rates` / `pricing_settings`), the **consignee master list**, and bulletins — is gated behind `broker_is_approved()`. The Shell route-gating is UX only; RLS is the wall ([[Lara (Customer Assistant)|Lara]] is also hidden for pending). Closes the self-signup data-exposure surface. Verified: every `FOR ALL` policy is staff-scoped (no bypass); approved customers + staff read everything; pending read nothing.

## Consent + definer gates (`0162`)

Some gates can't live in RLS alone: a SECURITY DEFINER function **bypasses RLS**, so the recorded-consent check (`has_recorded_consent()`) is enforced **inside** `file_job_order` / `open_ticket`, and the consent columns are server-stamped via a guard-trigger flag — see [[Broker Agreement]].

## The `useBroker` consequence

Because admin policies return **all** broker rows, a naive `select().maybeSingle()` breaks for admins. `useBroker` therefore **must** filter `.eq('user_id', uid)`. This is the bug that previously dumped the owner into the broker portal.

## Source of truth

The migrations under `supabase/migrations/` are authoritative for exact policies. This note is a conceptual summary — verify policy detail against the SQL before relying on it (idempotent style: `drop policy if exists` then `create policy`).

## Caveats

- Production-only runtime (no staging). Changes land on live data.
- Confirm you are operating on the KTC project (`mdlnfhyylvapzdubhyic`), not jta-sys, before any policy change. See `docs/agent/runtime-data-safety.md`.

## Related

- [[Authentication]] · [[Operational Invariants]] · [[Owner Failsafe]]
- ADR-0002
