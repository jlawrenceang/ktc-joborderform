---
title: Job Order Submission
tags: [workflow, job-orders]
type: workflow
---

# 🔄 Job Order Submission

How an approved broker submits a Job Order for terminal services.

## Steps

1. **Open** — approved broker goes to `/job-order` (New Job Order).
2. **Pick consignee** — search the **consignee master list** by code/name (debounced typeahead) and select one. No per-broker accreditation is required (disabled 2026-06-09; see ADR-0007).
3. **Add service requests** — one or more container lines, each with a service from `SERVICE_REQUESTS` (X-ray, DEA variants, OOG stripping).
4. **Submit** — `job_orders` header + `job_order_lines` written.
5. **Track** — broker sees it under `/job-orders`; staff process it under `/admin/job-orders`.

## Invariants

- Only **approved brokers** reach the form (broker-approval gate unchanged).
- Consignee is selected from the master list (searchable; the 2,488-row list is queried server-side, past the 1,000-row select cap).
- Brokers see only their own job orders; admins see all (RLS).

## Changed 2026-06-09 (ADR-0007)

The previous flow required the broker to request **accreditation** per consignee and an admin to approve it before the consignee appeared here. That gate is **disabled** — the picker now searches the full master list. The `/accreditation` page is replaced with a notice (route kept), and the `accreditations` table + admin accreditation features are untouched, so the gate can be re-enabled later.

## Open

- Admin-side status/processing workflow on `/admin/job-orders` is maturing.

## Related

- [[Job Orders]] · [[Brokers]] · [[Consignees]] · [[Consignee Accreditation]]
