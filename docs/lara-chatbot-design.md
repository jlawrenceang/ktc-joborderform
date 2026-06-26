# Lara — KTC Customer Assistant (Design)

> **Status:** designed, not yet built · **Detailed blueprint:** [`lara-chatbot-spec.md`](./lara-chatbot-spec.md) (the full 74-node tree, queries, and EN→TL table)

## What Lara is

Lara is the KTC portal's **customer-side help assistant** — a warm, friendly guide that helps
customers (customs brokers) do the everyday things: file a Job Order, track an order, understand
charges and payment, check rates / vessels / Last Free Day, file a container release, and manage
their account. She greets people, points them to the right place, answers the common questions in
plain language, and — when she can't help — **opens a real support ticket** so a person follows up.

Persona: **Lara — "Live Automated Response Assistant."** Tone is warm, courteous, and patient;
never cold or robotic. She introduces herself simply ("Hi, I'm Lara — happy to help").

## The core decision: Lara is **not** an AI / LLM

Lara is a **deterministic, rule-based assistant** — a hand-written decision tree plus a keyword
matcher. There is no language model behind her. This is a deliberate design choice, not a
limitation:

- **No per-message cost and nothing to "drain."** An open AI assistant bills per use and can be
  abused; Lara runs free, and a malicious user can do nothing but tap buttons.
- **No wrong answers.** Her common questions have *exact* answers (an order's status, how to file,
  the rates page). A rule book is more reliable than a model that can hallucinate.
- **Instant + always available.** No external API to be slow or down.
- **The long tail is handled by a human, not a guess.** Anything Lara doesn't cover becomes a
  support ticket — a real person — rather than a confident-but-wrong AI reply.
- **An LLM fallback can be added later** (gated, rate-limited, hard-capped) *if* ticket data shows
  customers keep asking open-ended questions the tree misses. Designed-for, not built.

This matches the field's own guidance: rule-based bots shine on clear-goal, high-volume, standard
tasks, and the winning pattern is *buttons for common actions, free text as the backup*, with a
*tiered* fallback that ends in a human hand-off.

## Best practices baked in (researched)

Each of these is a researched best practice, mapped to how Lara implements it:

1. **Buttons-first, free text as backup.** Keyword matching is brittle (people phrase things many
   ways), so Lara leads with tiles/quick-replies; the always-on text box is the flexible path.
   ([parallelhq](https://www.parallelhq.com/blog/chatbot-ux-design), [chatbot.com](https://www.chatbot.com/chatbot-best-practices/))
2. **Always a way back.** Every screen offers "Back to menu" / topic options — people change their
   minds mid-flow. ([Jotform](https://www.jotform.com/ai/agents/chatbot-conversation-flow/))
3. **Never repeat yourself.** Conversation state carries context (`vars`, `lastUserText`); a typed
   JO number flows straight into the track result. ([neuronux](https://www.neuronux.com/post/ux-design-for-conversational-ai-and-chatbots))
4. **Tiered, graceful fallback.** A miss offers a rephrase / the topic menu first, *then* a ticket —
   not an instant dead end. Good fallback recovers most failing conversations. ([beefed.ai](https://beefed.ai/en/chatbot-fallback-escalation), [com.bot](https://blog.com.bot/handling-chatbot-errors-techniques-and-fallback-strategies/))
5. **Two-strike rule → ticket.** If Lara misunderstands twice, she stops guessing and offers to
   open a ticket. No frustrating loops.
6. **Escalation done right.** "Talk to a person" is a **standing** quick-reply (visible, not buried);
   the ticket is **pre-filled with the user's own words + the right category** so they don't re-type;
   she sets the expectation that a person will follow up. ([Cobbai](https://cobbai.com/blog/chatbot-escalation-best-practices))
7. **Tool-based truth.** "Track an order" is a real, RLS-scoped database lookup — Lara reports the
   actual status, she never guesses it. ([AppMaster](https://appmaster.io/blog/rule-based-llm-chatbots-support))
8. **Scoped to what rule-based does best** — the known, high-volume KTC questions; open-ended advice
   is the ticket's job. ([Robylon](https://www.robylon.ai/blog/rule-based-vs-ai-powered-chatbots-2025))
9. **Measurable.** Watch **fallback rate** and **fallback-to-ticket ratio**; if many tickets cluster
   on the *same* question, that's the signal to add a tile/answer for it. Lara improves by watching
   where she fails. ([beefed.ai](https://beefed.ai/en/chatbot-fallback-escalation))

## Conversation design

**Six topic tiles** open the chat, plus a standing "Talk to a person" and an always-on text box:

| Glyph | Tile | Covers |
|-------|------|--------|
| 📦 | **File a Job Order** | how to file, what's needed, X-Ray / DEA / OOG, supplements |
| 🔎 | **Track an order** | type a JO number → live status + payment state |
| 💳 | **Charges & payment** | how to pay, bank / GCash / QRPH, proof upload, RPS, invoice/OR |
| 🚢 | **Rates, vessels & Last Free Day** | estimate charges, vessel schedule, what LFD means |
| 📤 | **Container release / pull-out** | how to file a release, documents, the after-flow |
| 🪪 | **Account & verification** | approval, valid ID, why pending, change email/password/contact |
| 🧑‍💼 | **Talk to a person** | standing quick-reply → opens a support ticket |

- **74 nodes** in one typed `NodeRegistry`, of six kinds: `message` (canned answer), `options`
  (buttons), `input` (capture one line, e.g. a JO number), `nav` (send into the real app at a
  route), `action` (a deterministic DB lookup), `ticket` (the fallback).
- **The matcher:** a typed JO number (`^JO-?\d{1,6}$`) jumps straight to the track result; otherwise
  a keyword/synonym match routes to the best topic; no match → a graceful "let me get a person on
  this" → ticket.

Full node-by-node tree, copy, and queries: [`lara-chatbot-spec.md`](./lara-chatbot-spec.md).

## Engine architecture

- **Files:** `src/components/chat/{types,nodes,match,actions,useChat,ChatWidget}.ts(x)`.
- **State:** `useReducer`-driven `ChatState` (current node, transcript, captured vars, busy). Pure
  except two async edges — `runAction` (the track lookup) and `openTicket`.
- **Mount:** `<ChatWidget/>` in **`src/components/Shell.tsx` only** (customer side — not staff),
  guarded so it never shows on a locked screen, portaled to `document.body` (floating launcher).
- **No new route, table, or migration.** Lara reads existing data and creates tickets through the
  existing `open_ticket` RPC.

## The track-order action (deterministic, RLS-scoped)

Reads `job_orders` by `jo_number` (parameterized `.eq(...).maybeSingle()`, no string interpolation),
pulls status + RPS/payment columns + supplement payment states, and renders a status + payment pill
via the existing `joPaymentState(...)` helper. RLS already scopes the row to the signed-in customer,
so a customer can only ever track their own order. A held draft (no JO number yet) returns no row and
is routed to "My Job Orders."

## The support-ticket fallback

The genuine escape hatch. Uses the **existing** customer ticket RPC verbatim:

```ts
supabase.rpc('open_ticket', { p_subject, p_category, p_body })
```

- **Category** is one of the 8 real keys (`app_system | customer_service | operations | account |
  accreditation | job_order | payment | other`) — chosen by where the conversation dead-ended.
- **Pre-fill:** a subject prefix (e.g. `Payment: `) + the user's *own words* as the first message —
  so the ticket is meaningful and they don't repeat themselves.
- **Fallback-of-the-fallback:** if `open_ticket` errors, Lara surfaces the admin-managed
  `support_contact` phone/email as `tel:` / `mailto:` links.

## Localization

All copy goes through the app's `t('English')` i18n. ~150 new English keys + their Tagalog land in
`translations.ts` (full EN→TL table in spec §11), de-duped against existing keys before insert.

## Prior art (GitHub scan)

What's out there for non-LLM chatbots, and why we build our own lean engine:

- **[LucasBassetti/react-simple-chatbot](https://github.com/LucasBassetti/react-simple-chatbot)** —
  the classic decision-tree React chatbot; the closest model to Lara (steps == our nodes). Actively
  maintained.
- **[FredrikOseberg/react-chatbot-kit](https://github.com/FredrikOseberg/react-chatbot-kit)** —
  a kit built around a *MessageParser* + *ActionProvider* + config; our `match.ts` / `actions.ts`
  split mirrors exactly this separation.
- **BotUI** — linear conversational UI (older; simpler than we need).
- Most repos returned for "rule-based chatbot" are **Python learning projects** (Streamlit/Flask
  command-line demos), not production widgets.

**Decision:** **build our own** lightweight engine rather than adopt a library. A dependency like
react-simple-chatbot would fight our design system, our `t()` i18n, our Supabase actions, and our
ticket fallback — and add bundle weight — for a tree we can express in a small typed registry. The
libraries above *validate the shape* (tree + parser + action-provider); we implement that shape
natively. ~6 small files, no runtime dependency.

## Open decisions (confirm before build)

From spec §12 — none block the design, but confirm so the build matches intent:

1. **~150 new i18n keys** land in `translations.ts` (the `t('English')` model you chose). OK.
2. **Track by JO number only** for now (entry numbers aren't unique). Defer entry-number lookup?
3. **6 tiles + standing "Talk to a person"** (labels/glyphs above). Confirm.
4. **"Vessel not listed" ticket** includes a one-line auto-summary of the path. OK?
5. **De-dupe** short labels ("Back to menu", "How do I pay?") against existing keys before insert. (I'll do this.)
6. **Launcher position** clears the mobile bottom tab-bar. (I'll verify the real tab-bar height.)

## Deferred (owner to supply the guide later)

Two release topics are intentionally **deferred** — for now Lara's release tile explains only the live online Release / Pull-out flow (ADR-0024):

- **Release pre-advise / advance-notice** — not built; Lara gives no guidance on it until the feature ships (matches the `nodes.ts` release-tile comment + `CHANGELOG.md`).
- **Document-verification guide content** — deferred; the **owner will supply the guide later**. Until then Lara's release nodes only name the live "Awaiting document check" step, not a detailed how-to.

## Build plan

1. `types.ts` + `nodes.ts` (the registry) + the EN→TL keys.
2. `match.ts` (matcher + synonyms) + `actions.ts` (track lookup) + `openTicket`.
3. `useChat.ts` (reducer/walker) + `ChatWidget.tsx` (launcher + panel, KTC styling).
4. Mount in `Shell.tsx`; verify; ship.
