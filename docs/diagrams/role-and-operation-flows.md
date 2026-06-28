---
title: Role & Operation Flows
tags: [diagrams, roles, workflow, reference]
type: reference
---

# KTC Online Portal — Role & Operation Flows

Detailed flowcharts of **every path each role can take**, the two operational spines
(Job Order + Release / Pull-out), and where the roles plug in. Diagrams are **Mermaid**
(render in GitHub, Obsidian, and most Markdown viewers).

**Source of truth:** synthesized from the live code + the **live `role_permissions`
table** and the SECURITY DEFINER RPC guards. Migrations through **0183** (the ADR-0035
job-order ops overhaul + the whole-app audit closure; verified 2026-06-27).

## How to read these

- **Rounded box** = screen/state. **Diamond** = decision/gate. **`[*]`** = start/terminal.
- Edge labels name the **action** and, in `[brackets]`, the **role/permission** that may take it.
- "Customer" = the accredited customs broker (non-staff). Staff roles: **owner, admin,
  operations, cashier, checker, csr**. **Owner bypasses every gate** (failsafe) and so is
  omitted from most edge labels — assume owner can do anything a gate allows.
- All writes go through **SECURITY DEFINER RPCs** gated by `has_permission()` (staff) or the
  `broker_*` helpers (customer); the UI only mirrors these — the server is the real gate.

---

## Roles, landings & permission matrix (verified against the live DB)

| Role | Lands on | Essence |
|---|---|---|
| **owner** | `/admin` | Failsafe — bypasses all gates; can edit the matrix itself |
| **admin** | `/admin` | Full back office; everything **except `confirm_xray`**; **approves** priority + re-X-ray; bills charges |
| **operations** | `/app/operations` | Accept orders + RPS + service completion + vessels; **monitors** X-ray (no confirm); **requests** priority / re-X-ray / charges; **no money, no file-on-behalf** |
| **cashier** | `/app/cashier` | **Money lane only** — payments + ERP invoice + **bills charges**; **no** accept/hold-reject/complete (dropped `0171`); **cannot** see the X-ray queue |
| **checker** | `/app/checker` | Confirms each van's X-ray entry (the spotter); **requests** re-X-ray |
| **csr** | `/app/support` | Support inbox + file-on-behalf + release doc verification + consignee request review + **requests** priority; **never** changes order status |
| **purchaser** | (appmap pending) | Fuel module: procurement + monitoring; **scoped, non-admin** |
| **customer** | `/` | Files/pays own Job Orders & Releases; sees only own data |

> **Landing change (current):** operational roles now land on their **focused staff-PWA screen** (`/app/*`),
> not the `/admin/*` page — the full back office is one tap away via "Open full portal". Only **owner/admin**
> land on `/admin`. (`RoleLanding`, `src/App.tsx`.)

Permission matrix (`✓` allowed · blank = denied · owner = `✓` on all):

| Permission | admin | operations | cashier | checker | csr | purchaser |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| view_job_orders | ✓ | ✓ | ✓ | ✓ | ✓ |  |
| view_xray_queue | ✓ | ✓ |  | ✓ | ✓ |  |
| view_fuel_reports | ✓ |  |  |  |  | ✓ |
| file_job_orders | ✓ |  |  |  | ✓ |  |
| accept_orders | ✓ | ✓ |  |  |  |  |
| process_job_orders | ✓ | ✓ |  |  |  |  |
| complete_orders | ✓ | ✓ |  |  |  |  |
| hold_reject_orders | ✓ | ✓ |  |  |  |  |
| confirm_xray |  |  |  | ✓ |  |  |
| request_priority | ✓ | ✓ |  |  | ✓ |  |
| approve_priority | ✓ |  |  |  |  |  |
| request_rexray | ✓ | ✓ |  | ✓ |  |  |
| approve_rexray | ✓ |  |  |  |  |  |
| request_supplement | ✓ | ✓ |  |  |  |  |
| bill_supplement | ✓ |  | ✓ |  |  |  |
| assess_rps | ✓ | ✓ |  |  |  |  |
| review_payments | ✓ |  | ✓ |  |  |  |
| record_invoice | ✓ |  | ✓ |  |  |  |
| log_fuel | ✓ |  |  |  |  | ✓ |
| manage_fuel | ✓ |  |  |  |  | ✓ |
| verify_release_docs | ✓ |  |  |  | ✓ |  |
| review_consignee_requests | ✓ |  |  |  | ✓ |  |
| manage_vessel_schedule | ✓ | ✓ |  |  |  |  |
| manage_support | ✓ |  |  |  | ✓ |  |
| manage_approvals | ✓ |  |  |  |  |  |
| manage_customers | ✓ |  |  |  |  |  |
| manage_consignees | ✓ |  |  |  |  |  |
| manage_pricing | ✓ |  |  |  |  |  |

**ADR-0035 maker-checker gates** (`0171`–`0177`): the six request/approve rows —
`request_priority`/`approve_priority`, `request_rexray`/`approve_rexray`,
`request_supplement`/`bill_supplement` — split *propose* from *approve/bill* so a requester can
never self-approve. **`0171` separation of duties:** CSR lost `accept_orders` / `hold_reject_orders`
(intake + comms only); cashier lost `hold_reject_orders` / `complete_orders` (money lane only).
**Completion is now automatic** — no role clicks "complete"; the order self-completes when the last
gate (services *or* payment) lands. **Confirming a base payment requires the ERP invoice + BIR pad
serial on file** (`record_service_invoice`, `0177`/`0178`).

---

## 1. Whole-operation overview

How a shipment moves through the portal, and which role drives each leg. Two independent
spines share one customer account and one back office.

```mermaid
flowchart TD
    REG["Customer registers → confirms email → uploads valid ID"]
    APPROVE{"Account approved?<br/>(admin · manage_approvals)"}
    REG --> APPROVE
    APPROVE -->|"no — pending/rejected/suspended"| GATEC["Verify-only (0163): every business surface<br/>hidden — no JO or Release filing until approved"]
    APPROVE -->|"yes"| HUB["Approved customer"]

    HUB --> JO0["File Job Order<br/>(special services: X-ray/DEA/OOG)"]
    HUB --> RL0["File Release / Pull-out<br/>(every container)"]

    subgraph JOSPINE["JOB ORDER spine — special services"]
      JO1["submitted<br/>(serving no. — regular · priority · re-X-ray lane)"] -->|"accept [operations/admin]"| JO2["processing"]
      JO2 --> JOX["X-ray per van CONFIRMED<br/>[checker · confirm_xray]"]
      JO2 --> JODEA["DEA/OOG service done<br/>[operations · process_job_orders]"]
      JO2 --> JORPS["RPS assessed (none/needed)<br/>[operations/admin · assess_rps]"]
      JO2 --> JOINV["cashier records ERP invoice + BIR pad no.<br/>[record_invoice] — REQUIRED before confirming base pay"]
      JOINV --> JOPAY["base + RPS + billed-supplement payments confirmed<br/>[cashier · review_payments]"]
      JOX --> JOGATE{{"Two-gate met?<br/>all services + all payments"}}
      JODEA --> JOGATE
      JORPS --> JOPAY
      JOPAY --> JOGATE
      JOGATE -->|"yes — AUTO-completes<br/>(no manual click)"| JODONE["completed"]
    end
    JO0 --> JO1

    subgraph RLSPINE["RELEASE / PULL-OUT spine — billing"]
      RL1["submitted"] -->|"verify docs [csr/admin · verify_release_docs]"| RL2["docs_verified"]
      RL1 -->|"hold (needs correction)"| RLH["on_hold"]
      RLH -->|"customer re-uploads"| RL1
      RL2 -->|"set charges, once [verify_release_docs]"| RL3["payable"]
      RL3 -->|"customer pays → confirm [cashier · review_payments]"| RL4["paid"]
      RL4 -->|"record OR + ERP no. [cashier · review_payments/record_invoice]"| RL5["released — pull-out"]
    end
    RL0 --> RL1

    OWN["owner / admin — oversight:<br/>approvals · customers · consignees · pricing · vessels · roles & gates · logs"]
    OWN -.governs.-> JOSPINE
    OWN -.governs.-> RLSPINE
```

---

## 2. Job Order spine — state machine

States: `held · submitted · processing · on_hold · completed · rejected · cancelled`.

```mermaid
stateDiagram-v2
    [*] --> submitted: approved customer / CSR-on-behalf files (jo_number + serving no. assigned)
    submitted --> processing: accept_orders [operations/admin]
    submitted --> on_hold: hold_reject_orders [ops/admin]
    submitted --> rejected: hold_reject_orders [ops/admin]
    submitted --> cancelled: cancel_job_order [customer]
    processing --> on_hold: hold_reject_orders [ops/admin]
    processing --> rejected: hold_reject_orders [ops/admin]
    on_hold --> submitted: resubmit_needs_info [customer, field-targeted]
    on_hold --> cancelled: cancel_job_order [customer]
    processing --> completed: TWO-GATE met — AUTO (services + payments)
    rejected --> [*]: terminal (no resubmit; use the on_hold path)
    cancelled --> [*]
    completed --> [*]
    note right of submitted
      held is legacy — pending customers are now
      verify-only (0163) and can no longer file
    end note
    note right of completed
      a charge billed after completion does NOT
      revert it (0183) — stays completed, flagged
      has_open_supplement until the charge is paid
    end note
```

**TWO-GATE completion** (`jo_ready_to_complete` + the `complete_on_payment_confirmed` /
`complete_on_service_done` triggers + `enforce_two_gate_complete` backstop) — `processing → completed`
fires **automatically** (no role clicks "complete") when **all** hold:

```mermaid
flowchart LR
    G1["All service lines done<br/>X-ray: every van confirmed [checker]<br/>DEA/OOG: [operations]"]
    G2["Base payment confirmed<br/>[cashier · review_payments]<br/>(ERP invoice + BIR pad recorded first)"]
    G3["RPS cleared<br/>not needed, OR paid+confirmed"]
    G4["Every BILLED supplement confirmed<br/>JO-####-A/B/C… (un-priced 'requested' don't block)"]
    G1 --> DONE{{"all true?"}}
    G2 --> DONE
    G3 --> DONE
    G4 --> DONE
    DONE -->|"yes — auto"| C["completed + completed_at stamped"]
    DONE -->|"any open"| P["stays processing"]
```

### 2a. Serving lanes + escalations — priority & re-X-ray (ADR-0035)

The serving number is assigned/vacated **automatically** on status (`serving_numbers_on_status`, `0173`):
it lands on `submitted`/`processing` and vacates (→ off the board) on `on_hold`/`rejected`/`cancelled`/`completed`.
Returning to the line gets a **new tail number** (the manual `restore_serving_number` queue-jump was dropped,
`0182`). Three lanes run in parallel — **regular**, a **priority** lane served first, and a **re-X-ray** child
lane — each numbered independently; the checker/operations queue sorts **priority → regular → re-X-ray**.

```mermaid
flowchart TD
    SUB["submitted / processing<br/>(regular lane)"]
    SUB -->|"request_priority [csr/ops]"| PREQ["priority: requested"]
    PREQ -->|"review_priority approve [admin]"| PGR["priority: granted<br/>→ priority lane (served ahead)"]
    PREQ -->|"review_priority deny [admin]"| SUB

    DONE2["completed order"]
    DONE2 -->|"request_rexray [checker/ops]<br/>builds child JO-####A"| RREQ["child: rexray_status=requested<br/>(customer-invisible, can't cancel/edit)"]
    RREQ -->|"review_rexray approve [admin]<br/>(+ billable?)"| RAP["child processing → re-X-ray lane<br/>own per-van X-ray + lifecycle"]
    RREQ -->|"review_rexray deny [admin]"| RCAN["child cancelled"]
    RAP -->|"free (default): services-done completes<br/>billable: + payment"| RDONE["child completed"]
```

> A re-X-ray child can't be X-rayed before admin approval (`record_van_xray` guard, `0181`), can't be
> accepted via the generic `accept_orders` path (`0178`), and emits **no** customer notifications (it's
> internal); `request_rexray`/`request_supplement` instead **ping staff** by gate (`notify_staff`, `0183`).

---

## 3. Release / Pull-out spine — state machine

States: `submitted · docs_verified · payable · paid · released · on_hold · cancelled`.
Customer must be **approved** to file (no held/pending path, unlike JOs).

```mermaid
stateDiagram-v2
    [*] --> submitted: file_release_order [approved customer] (RO-###### assigned)
    submitted --> docs_verified: verify ok [csr/admin · verify_release_docs]
    submitted --> on_hold: verify rejects doc [verify_release_docs]
    on_hold --> submitted: resubmit_release_doc [customer]
    docs_verified --> payable: set_release_charges — SET ONCE, non-zero [verify_release_docs]
    payable --> paid: submit_release_payment [customer] then confirm_release_payment [cashier]
    paid --> released: record_release_or [cashier · review_payments/record_invoice]
    submitted --> cancelled: cancel_release_order [customer/staff]
    docs_verified --> cancelled: cancel_release_order [customer/staff]
    payable --> cancelled: cancel_release_order [customer/staff]
    on_hold --> cancelled: cancel_release_order [customer/staff]
    released --> [*]
    cancelled --> [*]
```

**Additional charges & the OR block** — base charge is set **once**; anything missed is a
**supplement** the customer pays separately, and the **OR is blocked until every supplement
is confirmed**:

```mermaid
flowchart LR
    A["add_release_charge<br/>[csr/admin · verify_release_docs]<br/>on payable or paid"] --> S["release_supplements row (unpaid)"]
    S -->|"customer uploads proof"| SUB["submitted"]
    SUB -->|"confirm [cashier · review_payments]"| CONF["confirmed"]
    SUB -->|"reject"| REJ["rejected → customer re-uploads"]
    REJ --> SUB
    CONF --> OR{{"record_release_or:<br/>all supplements confirmed?"}}
    OR -->|"yes + OR no.(≤6) + ERP OR-INV(8), non-zero, cash"| REL["released"]
    OR -->|"any unpaid"| BLOCK["BLOCKED — settle first"]
```

---

## 4. Per-role flows

### 4.1 Customer (customs broker)

```mermaid
flowchart TD
    L["/login — register or sign in"] --> CONF{"email confirmed?"}
    CONF -->|"no"| AWAIT["Awaiting confirmation (resend)"]
    CONF -->|"yes"| VID["/verify-id — upload ID or skip"]
    VID --> ST{"account status"}
    ST -->|"pending"| PEND["Verify-only — every business surface hidden<br/>until an admin approves (0163)"]
    ST -->|"rejected"| REJ["PendingPanel — fix + resubmit details/ID"]
    ST -->|"suspended"| SUS["PendingPanel — terminal, contact support"]
    ST -->|"approved"| OK["Full access"]

    OK --> FJO["/job-order — file JO → submitted"]
    PEND --> NOFILE["✗ Cannot file — verify-only until approved"]
    OK --> FRL["/releases — file Release → submitted"]

    OK --> MJO["/job-orders — manage"]
    MJO --> EDIT["Edit (submitted; locks at processing)"]
    MJO --> RESP["Respond to field-targeted hold → submitted"]
    MJO --> CAN["Cancel (submitted/on_hold) → cancelled"]
    MJO --> PAY["Pay base / RPS / supplements (upload proof)"]
    MJO --> PRINT["Print slip (submitted onward)"]

    OK --> MRL["/releases — manage"]
    MRL --> RDOC["Resubmit doc (on_hold) → submitted"]
    MRL --> RPAY["Pay (payable) + each supplement"]
    MRL --> RCAN["Cancel (pre-payment) → cancelled"]
    MRL --> RCLAIM["paid → claim OR at office"]

    OK --> SUP["/support — open/reply tickets, escalate"]
    OK --> ACC["/account — name (→re-verify), email, password"]
    OK --> BROWSE["/vessels · /calculator · /manual (read-only)"]
```

**Customer is blocked from:** filing anything while **pending** (verify-only, `0163`); editing an order
once `processing`; cancelling once `processing` (JO) or once `paid` (release); resubmitting a `rejected`
order (terminal — use the field-targeted `on_hold` path); touching an internal **re-X-ray** child;
requesting or pricing charges; confirming any payment; filing a Release while not `approved`.

### 4.2 Owner

```mermaid
flowchart TD
    O["/admin — Dashboard"] --> ALL["Bypasses EVERY gate (failsafe)"]
    ALL --> A1["Everything admin can do (below)"]
    ALL --> A2["create_staff — invite staff (username+password)"]
    ALL --> A3["Roles & Gates — edit the permission matrix"]
    ALL --> A4["set_owner_access — root-only owner grants"]
    ALL --> A5["confirm_xray fallback (admin cannot)"]
    ALL --> A6["Cannot be revoked / locked out"]
```

### 4.3 Admin

```mermaid
flowchart TD
    AD["/admin — Dashboard"] --> AP["Approvals — approve/reject customers & consignees<br/>[manage_approvals] → unblocks the verify-only customer (filing + releases)"]
    AD --> CU["Customers — suspend/edit [manage_customers]"]
    AD --> CO["Consignees — manage master list [manage_consignees]"]
    AD --> PR["Settings — rates/fees/pricing [manage_pricing]"]
    AD --> VE["Vessel schedule [manage_vessel_schedule]"]
    AD --> JOA["Job Orders — accept/hold/reject [accept/hold_reject_orders] · complete is AUTO"]
    AD --> APRX["Approve priority + re-X-ray requests<br/>[approve_priority / approve_rexray]"]
    AD --> RPSa["Assess RPS [assess_rps]"]
    AD --> PAYa["Confirm payments + record ERP invoice (req. before base confirm) + bill charges<br/>[review_payments / record_invoice / bill_supplement]"]
    AD --> RELa["Release docs desk: verify + set charges [verify_release_docs]"]
    AD --> SUPa["Support inbox [manage_support]"]
    AD --> LOGS["Logs / audit [manage_approvals]"]
    AD --> NOX["✗ Cannot confirm X-ray (checker-only)"]
```

### 4.4 Operations

```mermaid
flowchart TD
    OP["/app/operations (full portal one tap away)"] --> ACC["Accept submitted → processing [accept_orders]"]
    OP --> HR["Hold / reject [hold_reject_orders]"]
    OP --> SVC["Mark DEA/OOG/other service done [process_job_orders]"]
    OP --> RPS["Assess RPS — none / per-move [assess_rps]"]
    OP --> REQ["Request priority / re-X-ray / charge<br/>[request_priority · request_rexray · request_supplement] → admin/cashier acts"]
    OP --> XV["X-ray Queue — MONITOR only [view_xray_queue]"]
    XV --> NOC["✗ No Confirm button (no confirm_xray)"]
    OP --> VES["Vessel schedule [manage_vessel_schedule]"]
    OP --> NOM["✗ No payments/billing · no release docs · no file-on-behalf · completion is AUTO (no Complete button)"]
```

### 4.5 Cashier

```mermaid
flowchart TD
    CA["/app/cashier (full portal one tap away)"] --> Q3["Record ERP invoice + BIR pad no. (JO)<br/>[record_invoice] — REQUIRED before confirming base pay"]
    Q3 --> Q1["Review online payment proofs — confirm/reject [review_payments]"]
    CA --> Q2["Record walk-in / office payment [review_payments] (also invoice-gated)"]
    CA --> QB["Bill a requested charge — set amount → payable [bill_supplement]"]
    CA --> Q4["Confirm/reject release payments + supplements [review_payments]"]
    CA --> Q5["Record release OR + ERP control no. → released [review_payments/record_invoice]"]
    CA --> NOQ["✗ No X-ray queue · ✗ no accept/RPS · ✗ no hold-reject/complete (dropped 0171) · ✗ no release-doc verify"]
```

### 4.6 Checker (X-ray spotter)

```mermaid
flowchart TD
    CK["/app/checker — X-ray Queue (full portal one tap away)"] --> SCAN["Open a JO's container vans<br/>(queue sorts priority → regular → re-X-ray lane)"]
    SCAN --> CONF["Confirm X-ray entry per van [confirm_xray] → record_van_xray"]
    CONF --> SIG["Stamps e-signature (name+time) per van"]
    CONF --> LAST{"last van?"}
    LAST -->|"yes"| ROLL["X-ray service rolls up to done → may auto-complete if paid"]
    LAST -->|"no"| SCAN
    CK --> RRX["Request re-X-ray on a completed order [request_rexray] → admin approves"]
    CK --> ONLY["✗ No accept/hold/reject/complete · ✗ no edit · ✗ no payments"]
```

### 4.7 CSR (customer service)

```mermaid
flowchart TD
    CS["/app/support — inbox (full portal one tap away)"] --> TIX["Open/read/reply/close tickets, escalate (call/email/SMS/Viber) [manage_support]"]
    CS --> FILE["File a Job Order on behalf of a customer [file_job_orders]"]
    CS --> RVER["Release documents desk — verify / hold DO/BL [verify_release_docs]"]
    CS --> RCHG["Set release charges (once) + add charge [verify_release_docs]"]
    CS --> RCQ["Review consignee requests [review_consignee_requests]"]
    CS --> RPRI["Request priority on an order [request_priority] → admin approves"]
    CS --> XV["View X-ray queue (read) [view_xray_queue]"]
    CS --> NONE["✗ No order status changes (accept/hold/reject) · ✗ no payments · ✗ no confirm X-ray"]
```

---

## Cross-role hand-off summary

| Hand-off | From → To | Gate |
|---|---|---|
| Account approval unblocks filing | admin → customer | `manage_approvals` |
| JO accepted into processing | operations/admin | `accept_orders` |
| X-ray confirmed per van | checker | `confirm_xray` |
| DEA/OOG done · RPS assessed | operations/admin | `process_job_orders` · `assess_rps` |
| Payments confirmed (JO + release) | cashier/admin | `review_payments` |
| ERP invoice recorded (**required before base-pay confirm**) / release OR recorded | cashier/admin | `record_invoice` / `review_payments` |
| Priority granted | csr/ops request → admin approve | `request_priority` → `approve_priority` |
| Re-X-ray approved | checker/ops request → admin approve | `request_rexray` → `approve_rexray` |
| Charge billed (ops never bills directly) | ops request → cashier bill | `request_supplement` → `bill_supplement` |
| Release documents verified | csr/admin | `verify_release_docs` |
| Release charges set / supplements | csr/admin | `verify_release_docs` |
| Support handled | csr/admin | `manage_support` |

> Verified 2026-06-27 against the live `role_permissions` table + the RPC guards in
> `supabase/migrations/**` through 0183 (ADR-0035 ops overhaul + audit closure). If a gate is re-toggled
> in **Settings → Roles & Gates**, this matrix and these flows change with it — the server enforces the
> live matrix, not this doc.
