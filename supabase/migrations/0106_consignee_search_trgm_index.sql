-- ============================================================
-- 0106 — fast consignee typeahead at scale (owner, 2026-06-16)
--
-- Load-test finding: the consignee picker (src/lib/pickerSearches.ts) runs
--   ...where code ilike '%q%' or name ilike '%q%' order by code limit 40
-- with NO trigram index, so every keystroke is a full sequential scan of the
-- consignees table (both columns). At ~6k consignees under concurrent searches
-- this is the dominant cost: the slow scans hold PostgREST pool connections and
-- the pool exhausts ("Timed out acquiring connection from connection pool" /
-- statement timeout) above ~150–200 concurrent reads — while the indexed write
-- path (500 concurrent filings) stayed clean. A GIN trigram index turns the
-- contains-ILIKE into an index scan, removing the bottleneck and raising read
-- concurrency headroom dramatically.
-- ============================================================

create extension if not exists pg_trgm;

create index if not exists consignees_name_trgm on public.consignees using gin (name gin_trgm_ops);
create index if not exists consignees_code_trgm on public.consignees using gin (code gin_trgm_ops);

analyze public.consignees;
