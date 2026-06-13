# Reference documents — real KTC paper forms

Sample paper documents from KTC operations (provided 2026-06-13), kept as the **format-of-record** behind the X-Ray JO modernization and the port-services (RPS) per-move billing build. They show the real fields/flows we are digitizing.

> ⚠️ These scans contain **real client data** (company names, TINs, broker names, container numbers). The repo is private; treat as confidential and do not surface in any public artifact.

| File | What it is | Role in the build |
|---|---|---|
| `xray-examination-joborder-sample.jpg` | **X-Ray Examination job order** (No. 139) — customer, vessel, voyage, date, container-number list, serving number, PAID stamp | **The current paper JO we are modernizing.** The portal Job Order replaces this. Confirms the JO field set: customer, **vessel + voyage**, container numbers, serving number. (Packages / cargo nature / gross weight are NOT needed — owner decision 2026-06-13.) |
| `request-for-port-services-rps-sample.jpg` | **Request for Port Services (RPS)** — lists port services with a **number of MOVES** each (Shifting, Stuffing, Trucking, Lift On/Lift…), "chargeable", approved + PAID by KTC staff | The source document for **per-move** port-services charges. A DEA selection routes a JO to **RPS review**: staff upload the RPS and enter the move counts → system computes the total. |
| `service-invoice-sample.jpg` | **KTC Service Invoice** (No. 094276 / OR-INV-…) — line items = service × **moves (qty)** × unit price + 12% VAT | The cashier's BIR billing output (lives in the Frappe ERP). Source of the per-move **unit prices**: Shifting (M/HC) ₱950.86, Foreign Hustling/Trucking ₱1,000.00, Lift On ₱730.83. |
| `import-entry-sad-sample.jpg` | **Import Entry / customs declaration (SAD)** — broker's BOC entry for the shipment | An **entry document** — supporting paperwork; source of consignee, vessel/voyage, container numbers. Not a KTC pricing doc. |
| `bill-of-lading-sample.jpg` | **Bill of Lading** (non-negotiable) — ocean BL for the shipment | An **entry document** — context for cargo/containers. Not a KTC pricing doc. |
| `vessel-schedule-sample.jpg` | **KTC vessel schedule** — Vessel Name · Voyage Number · **Vessel Visit** · Actual Date Arrival · Finish Discharging · **Last Free Day of Storage** · Berth | The real format for the `vessel_schedule` table + JO vessel/voyage dropdown. "Vessel Visit" is the call's natural key (seed of the TOS vessel-call entity); "Finish Discharging" + "Last Free Day of Storage" are the **storage/demurrage clock**. |

## Decisions captured from these docs (2026-06-13)

- **Modernized X-Ray JO fields:** add **vessel + voyage** (everything else on the form — packages, cargo nature, gross weight — is *not* needed). Vessel + voyage = a **dropdown from a vessel schedule**; customers may only pick an **active** vessel/voyage.
- **DEA pricing = per-move breakdown (not a flat per-van rate).** DEA is rare. Selecting DEA routes the JO to **RPS review**: KTC personnel **upload the RPS** and enter the **number of moves** per move-type; the system multiplies by admin-configured per-move rates to generate the total. (Move-type rates seed from the Service Invoice above; admin-editable like `service_rates`.)
- **X-Ray stays flat ₱2,918/van** (VAT-exclusive). Combined "X-Ray + DEA" = ₱2,918 + the RPS per-move total (pending final confirm).

See the backlog in `docs/obsidian-vault/07-Memory/Pending Items.md` and the TOS direction in `docs/obsidian-vault/09-Future/Terminal & Depot Operating System (North Star).md`.
