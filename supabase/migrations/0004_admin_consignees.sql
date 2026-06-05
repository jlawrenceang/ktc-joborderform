-- ============================================================
-- 0004 — let admins manage the consignees master list (for the uploader).
-- (Brokers still only read consignees; writes are admin-only.)
-- ============================================================

drop policy if exists "admin inserts consignees" on public.consignees;
create policy "admin inserts consignees" on public.consignees
  for insert to authenticated with check (public.is_admin());

drop policy if exists "admin updates consignees" on public.consignees;
create policy "admin updates consignees" on public.consignees
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin deletes consignees" on public.consignees;
create policy "admin deletes consignees" on public.consignees
  for delete to authenticated using (public.is_admin());
