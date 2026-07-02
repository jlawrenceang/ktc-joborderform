# Domain knowledge — operations & supply-chain models for this portal

Canonical starting models for terminal/port/depot features, seeded 2026-07-02 from the framework's
full triage of an operations-and-SCM textbook (provenance: the framework repo's
`reference-library/operations-scm-mba-triage-2026-07-02.md`, repo-only — the mechanisms below are
self-contained; the pointer is provenance, not a dependency). **Consult the matching row BEFORE
building or extending a domain feature** — start from the canonical model, don't improvise one.
Each row: model → what it computes/decides → where it lands in THIS portal.

| Model | Mechanism (one line) | Where it applies here |
|---|---|---|
| **Landed cost / total cost of ownership** | True cost = price + freight + duty + currency + inspection + risk, never unit price alone | `Calculator.tsx` / tariff features — upgrade from rate lookup toward landed-cost quoting; any broker/route comparison |
| **Door-to-door SLA** | The customer judges TOTAL order-to-delivery across every handoff leg, not any single party's segment | Job-order tracking + releases/pull-out: measure vessel-arrival → gate-out end-to-end, not just the terminal's own leg |
| **Chain of custody / track-and-trace** | Item-level events on an append-only trail reconstruct custody in seconds (recalls, origin proof) | Checker/X-ray per-van e-sig flow + `ChargeAuditView` — the audit spine is already the right shape; extend per-container event history |
| **Yield management + overbooking** | Allocate fixed perishable capacity (slots) by class, overbook against measured no-show rate | X-ray/inspection queue slots, vessel-schedule berth/appointment windows, gate slots |
| **Shared-forecast workspace (CPFR-shape)** | Partners converge on ONE shared schedule/forecast instead of private stale copies | `VesselSchedule`/`VesselCalendar` shared with brokers + consignees; filing-deadline visibility both sides |
| **Concentration-risk alert** | Flag when >X% of volume/spend runs through one broker, carrier, or lane — one failure stalls the whole flow | Reports over job orders per broker/consignee; an admin alert tile |
| **Reverse logistics taxonomy** | Classify a return (commercial / end-of-use / warranty / re-export) to route its disposition path — incl. duty-drawback on re-exported imports | Pull-out & release flows; any future re-export / empty-return handling |
| **Working-capital KPIs (CCC, aging)** | Days cash is tied up = DIO + DSO − DPO; receivables aging drives collection priority | Charges/billing + `Reconciliation.tsx` dashboards — the cashier desk's health tiles |
| **Multi-echelon surge check** | "Can we absorb this volume?" must test EVERY stage (gate, yard, x-ray, cashier, release) and name the binding one | Capacity/what-if reporting when a large vessel call or seasonal spike is scheduled |
| **Queueing law (cycle time = WIP ÷ throughput)** | Time-in-yard rises sharply as utilization nears 1 — from variability alone, before "overload" | Yard-dwell and desk-queue analytics; staffing the cashier/checker desks against arrival rates |

Rules of use: these are **starting models, not mandates** — the spec still confirms fit with the owner;
domain vocabulary stays in this repo (see `denylist.txt` — never promote client terms into the global layer).
