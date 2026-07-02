<!-- NOTE (2026-07-02): the .html beside this file is now HAND-CRAFTED (customer-facing vision deck,
     owner-directed redesign) — do NOT regenerate it with tools/deck.mjs from this outline.
     This .md remains the internal content outline; the plan .md remains the source of truth. -->
<!-- layout: cover -->
# KTC · Five-Year Roadmap
## From Online Portal to Terminal + Depot Operating System
Executing ADR-0015 (Octopi-class, container spine first) · 2026 → 2031
<!-- notes: The plan doc (same folder, same date) is the source of truth; this deck is the walkthrough. -->

---
## Where we stand — mid-2026

- Portal **v2.0.x at the last go-live stations** — 184/184 read-only battery, break-test closed, blind walk done
- Money spine **sound** (8 billing invariants)
- The container itself: **still off-system** — the single biggest missing foundation
- Reference class decided: **depot-tier, never enterprise-TOS** (small terminals pay enterprise prices and use ~30% of the features)

---
## The thesis (already ratified — ADR-0015)

Build the **container data spine** first:

- `containers` — ISO 6346-keyed, check-digit validated, owner line + grade
- `container_events` — **append-only; the source of truth** (every "current state" is derived)
- **EIR** at every gate event — photos, damage codes, signatures

Every later module is a projection over this spine. In a custodian business, **the audit trail is the product**.

---
## Year 1 · Operate, then lay the spine

**H1:** finish the four open stations (mutating e2e → roast at 90 → ST08 side-by-side → go/no-go + watch window) — then operate, boring on purpose
**H2:** the spine + e-EIR gate v1, reusing patterns the portal already has (e-sig, upload/review, serving queues)

*Exit: every gate crossing spine-recorded for 60 days straight.*

---
## Year 2 · Gate ops + depot M&R — the revenue core

- Gate: appointments · weighbridge/**VGM** (calibration expiry = a monitored system fact) · TAPP-accredited trucker registry
- **M&R: survey → CEDEX-coded estimate → line approval → repair → release** — the defining depot workflow, billable end-to-end
- Storage billing: day-counted from the movement record, per-line free time + per-diem

*Exit: one full M&R cycle in production for ≥2 lines; a quarter of auto-derived storage invoices.*

---
## Year 3 · Yard truth + billing generalization

- Yard map: block/bay/row/tier · occupancy is a **query, never a stored flag**
- Work orders: pull-based single-next-job queues
- Tariff engine: every invoice line = movement event × tariff row
- The kaizen metric: **rehandles per move** (the ideal is two touches)

---
## Year 4 · Integration — speak the lines' languages

- **Outbound adapters:** one internal event → EDIFACT CODECO *or* DCSA JSON per partner (the industry dual-speaks through the 2020s)
- **Universal inbox:** accept EDI, spreadsheets, PDF pre-advise, portal email — normalize internally; *never gate on the counterparty modernizing* (manual pre-advise is standard PH practice)
- BOC: **reconcile** e2m/E-TRACC — never file
- Start with ONE line, prove the round-trip, then the second

---
## Year 5 · Measure, optimize — and the option

- KPI layer: moves/hour · truck turn time · dwell · rehandles · M&R cycle time
- Berth scheduling only if vessel business grows (interval model, no optimizer)
- **The productization gate (owner decision, an ADR):** five years of operating our own depot on it = the demo; the market gap (web-native vs legacy roll-ups) is real; "*no — it stays KTC's edge*" is an equally valid outcome

---
## Execution: who builds what

- **Schema/spine, billing** — default-class, single-owner, `/spec` → `jarvis` always + eval invariants
- **Screens/CRUD** — Sonnet-class off the confirmed spec → roast at 90
- **EDI adapters** — default; red-tested on planted bad messages → fixture round-trips
- **Module go-lives** — the full 15-station line → owner side-by-side

**The fences hold:** no stowage optimization, no equipment automation, no BIR rebuild, no PCS — new evidence + an ADR, or not at all.

---
<!-- layout: quote -->
> Sequence by dependency, not visibility. The spine is invisible to customers — and it is the whole future.

**Owner's open questions (each gates a fork):** characterize the existing tooling · which pillar leads commercially · container-only or mixed cargo (blocks the Y1-H2 schema freeze).
