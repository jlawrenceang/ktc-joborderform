-- ============================================================
-- 0136 — the Customer Information Sheet belongs to the CONSIGNEE, not the broker.
--
-- 0133 wrongly modelled the CIS as a broker-account profile and gated ALL filing
-- on it. Correct model (owner, 2026-06-22): the CIS-with-documents accredits a
-- CONSIGNEE (the billed cargo-owner) — that's request_consignee (0132). The
-- "customer base" is one pool (a broker can also be a consignee), so there is ONE
-- CIS, held on the consignee record. Consignees are file-now/usable immediately;
-- ones missing their BIR docs are FLAGGED in the UI, never hidden or blocked.
-- So we tear down the entire 0133 broker-level gate.
-- (0134/0135 were taken by parallel tracks — hence this is 0136.)
-- ============================================================

drop trigger if exists job_orders_require_cis on public.job_orders;
drop trigger if exists release_orders_require_cis on public.release_orders;

drop function if exists public.enforce_customer_info_before_filing() cascade;
drop function if exists public.my_company_info_complete();
drop function if exists public.customer_info_complete(uuid);
drop function if exists public.save_customer_info(jsonb, jsonb, boolean);

drop table if exists public.customer_contacts;
drop table if exists public.customer_info;

-- Broker-doc storage (unused now). Remove its policies; the empty 'customer-docs'
-- bucket is left in place (Postgres blocks direct deletes from storage tables;
-- with no policies + no objects it is inert). Delete it via the Storage API if
-- you ever want it gone.
drop policy if exists "customer uploads own customer doc" on storage.objects;
drop policy if exists "customer updates own customer doc" on storage.objects;
drop policy if exists "customer reads own customer doc" on storage.objects;
drop policy if exists "staff reads customer docs" on storage.objects;
