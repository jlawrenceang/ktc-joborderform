# Security policy

This is a private, proprietary repository for a live client system. It is not open to public contribution.

## Reporting a vulnerability

Report suspected vulnerabilities privately to the maintainer: **jlawrenceang@gmail.com**. Include reproduction steps and affected surface; do not test against production data or accounts. Reports are acknowledged and triaged against the repo's security invariants (backend-enforced access, RLS, server-enforced auth challenges) and, where confirmed, fixed through the standard release gate with an independent verification pass.

## Scope notes

- No bug-bounty program is offered.
- Credentials, keys, and client data are never accepted in reports; a pre-commit secret scan and repository scanning enforce the same rule internally.
