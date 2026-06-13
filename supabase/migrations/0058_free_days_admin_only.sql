-- ============================================================
-- 0058 — free-storage-days setting is ADMIN-ONLY (owner decision A1, 2026-06-13)
--
-- The vessel SCHEDULE (vessel_schedule) stays operations-editable
-- (manage_vessel_schedule). But the free-days POLICY (shipping_lines) is a
-- commercial setting → admin-only, alongside rates/fees in Settings. Gate its
-- writes on manage_pricing (admin holds it; operations does not; owner bypasses).
-- ============================================================

drop policy if exists "manage shipping lines" on public.shipping_lines;
create policy "manage shipping lines" on public.shipping_lines
  for all to authenticated
  using (public.has_permission('manage_pricing'))
  with check (public.has_permission('manage_pricing'));
