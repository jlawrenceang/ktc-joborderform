# ADR-0007: Disable per-broker consignee accreditation (brokers pick from the master list)

* Status: Accepted
* Deciders: KTC project stakeholders (owner)
* Date: 2026-06-09
* Category: Workflow

## Context and Problem Statement

The original flow (ADR-0005) required a broker to request accreditation for each consignee, have an admin approve it, and only then could that consignee appear on the broker's Job Order form. In practice this is friction for prod testing: brokers have nothing to select until accreditations are processed. The question is whether to keep the per-broker accreditation gate or let a registered broker pick any consignee directly.

## Decision Drivers

* Get brokers transacting quickly during prod testing without an accreditation backlog.
* The consignee **master list** (2,488 imported) is the useful selection set.
* Admin-side consignee data quality (TIN, 2303) should remain, but shouldn't block job-order creation right now.
* The change must be reversible — re-enable per-broker accreditation later without rework.

## Considered Options

* **Option A** — Disable the per-broker accreditation gate; the Job Order consignee picker searches the full consignee master list. Keep broker account approval.
* **Option B** — Keep per-broker accreditation as-is.
* **Option C** — Restrict the picker to admin-approved consignees only (consignee `status='approved'`).

## Decision Outcome

Chosen option: **Option A**. The New Job Order page replaces the accreditation-fed dropdown with a debounced server-side **typeahead over the entire `consignees` master list** (searched by code/name; the 2,488-row list exceeds the 1,000-row select cap, so we search rather than preload). The broker account-approval gate is unchanged — only *approved* brokers reach the form. The `/accreditation` page and its nav link are removed/replaced with a notice; the route is kept so links don't break and the flow can be re-enabled. The `accreditations` table and all admin-side consignee accreditation features (address/TIN/2303/approval) are untouched in the DB.

### Positive Consequences

* Approved brokers can submit job orders immediately against any consignee.
* No accreditation backlog blocking prod testing.
* Fully reversible — re-point the picker at `accreditations` and restore the page/nav to revert.

### Negative Consequences / Trade-offs

* The "job orders only against approved consignees" invariant from ADR-0005 is relaxed: a broker can target any consignee in the master list, including un-accredited ones.
* No per-broker scoping — every broker sees the same master list.

## Pros and Cons of Options

### Option A: Master-list picker, no per-broker gate (chosen)

* Good, because brokers transact immediately; reversible; scales via search.
* Bad, because it relaxes the approved-consignee targeting control.

### Option B: Keep per-broker accreditation

* Good, because tightest control + per-broker scoping.
* Bad, because accreditation friction blocks prod testing now.

### Option C: Approved-consignees-only picker

* Good, because keeps the data-quality gate on targeting.
* Bad, because almost no consignees are approved yet, so the picker would be nearly empty — defeats the goal.

## Related ADRs

* Partially supersedes [ADR-0005](0005-admin-approval-and-consignee-accreditation-controls.md) (the per-broker accreditation gate; broker + consignee admin approval still stand). See the addendum on ADR-0005.

## References

* `src/pages/JobOrder.tsx` (master-list typeahead) · `src/pages/Accreditation.tsx` (notice) · `src/components/Shell.tsx` (nav)
* `docs/obsidian-vault/04-Workflows/Job Order Submission.md`
