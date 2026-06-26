---
title: Lara (Customer Assistant)
tags: [concept, support, chatbot, customer, frontend]
type: concept
last_updated: 2026-06-26
---

# 🤖 Lara — Customer Help Assistant

A floating **"Ask Lara"** widget on the customer side — a warm, guided help assistant for the everyday tasks (file a Job Order, track an order, understand charges/payment, check rates / vessels / Last Free Day, file a release, manage the account). Shipped v1.6.22 (2026-06-26). Persona: **Lara — "Live Automated Response Assistant."**

## The core decision: Lara is **not** an AI / LLM

Lara is a **deterministic, rule-based** assistant — a hand-written **93-node decision tree + keyword matcher**, no language model behind her. Deliberate, not a limitation:

- **No per-message cost and nothing to "drain"** — an open AI assistant bills per use and can be abused; Lara runs free, a malicious user can only tap buttons.
- **No wrong answers** — the common questions have exact answers (a status, how to file, the rates page); a rule book beats a model that can hallucinate.
- **Instant + always available** — no external API to be slow or down.
- **The long tail is a human, not a guess** — anything she doesn't cover becomes a support ticket.
- **An LLM fallback is designed-for, not built** — gated / rate-limited / hard-capped, added only *if* ticket data shows customers keep asking open-ended questions the tree misses.

## How it works

- **Buttons-first, free text as backup.** Six topic tiles (Orders · Vessel schedule · Rates & payment · Container release · Account & verification · Feedback & concerns) + a standing **"Talk to a person"** + an always-on text box. "Back to menu" everywhere; a **two-strike rule** → ticket (no frustrating loops).
- **Tool-based truth.** "Track an order" is a real **RLS-scoped** DB lookup (`job_orders` by `jo_number`, parameterized, `.maybeSingle()`) — reports the actual status + payment pill via the existing `joPaymentState(...)`. RLS already scopes the row to the signed-in customer, so a customer can only ever track their own order.
- **Support-ticket fallback.** Uses the existing `open_ticket` RPC verbatim, **pre-filled** with the user's own words + the right category (one of the 8 real keys), so stakeholder concerns (customs / shipping-line / logistics) become tagged tickets KTC can collate. Fallback-of-the-fallback: if `open_ticket` errors, Lara surfaces the admin-managed `support_contact` phone/email.

## Engine + boundaries

- **Files:** `src/components/chat/{types,nodes,match,actions,useChat,ChatWidget}.ts(x)` — a small typed node registry + matcher + actions + a `useReducer` walker. Own lean engine (not a library — would fight the design system / `t()` i18n / Supabase actions).
- **Mount:** `<ChatWidget/>` in **`src/components/Shell.tsx` only** (customer side — not staff), portaled to `document.body`, **hidden for pending/locked customers** (see [[RLS Posture]]).
- **No new route, table, or migration** — reads existing data, opens tickets through the existing RPC.
- **i18n:** all copy via `t('English')` — English + Tagalog ([[Localization (i18n)]]).
- **a11y** (v1.6.23): focus moves into the panel on open, Escape closes, focus restores to the launcher; transcript is an `aria-live` polite region.

## Status / deferred

- **Live**, customer-side. Design: `docs/lara-chatbot-design.md` (+ `docs/lara-chatbot-spec.md`).
- **Deferred (owner to supply):** the **document-verification guide** content (Lara's release tile gives a holding answer until then); **release pre-advise / advance-notice** (not built); the optional **LLM open-ended fallback** (needs an API key + caps).

## Related

- [[Support Tickets]] · [[Job Orders]] · [[Localization (i18n)]] · [[RLS Posture]]
- Design: `docs/lara-chatbot-design.md`
