-- ============================================================
-- 0060 — operations can't process/file JOs; vessel+voyage on the JO
-- (owner decisions 2026-06-13)
--
-- Operations is view + confirm X-ray + manage consignees + vessel schedule
-- (+ RPS assessment later). Processing and filing stay admin-only — so the
-- queue is read-only to operations and no broad write path is needed.
-- ============================================================

update public.role_permissions
   set allowed = false, updated_at = now()
 where role = 'operations'
   and permission in ('process_job_orders', 'file_job_orders');

-- Vessel + voyage captured on each JO, picked from the vessel schedule
-- (required in the form, A2). The escape hatch (vessel not yet listed) files
-- with vessel_visit left null + the typed name/voyage, so operations can
-- reconcile it to a scheduled call later.
alter table public.job_orders add column if not exists vessel_visit  text;
alter table public.job_orders add column if not exists vessel_name   text;
alter table public.job_orders add column if not exists voyage_number text;
