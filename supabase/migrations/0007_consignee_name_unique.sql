-- ============================================================
-- 0007 — duplicate guard: no two consignees with the same name
-- (case-insensitive). Code is already unique. Variant spellings
-- (e.g. "DOLE PHILS" vs "DOLE PHILIPPINES") remain allowed as distinct.
-- ============================================================

create unique index if not exists consignees_name_lower_key
  on public.consignees (lower(name));
