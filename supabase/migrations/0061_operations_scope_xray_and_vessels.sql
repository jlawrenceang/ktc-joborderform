-- ============================================================
-- 0061 — narrow operations to its real job (owner clarification 2026-06-13)
--
-- Operations does THREE things: (1) confirm a JO is for X-ray (intake — the
-- RPS-assessment surface, built later), (2) confirm X-ray finished (the
-- Checker station), (3) update the vessel schedule. So drop manage_consignees;
-- keep view_job_orders + confirm_xray + manage_vessel_schedule.
-- ============================================================

update public.role_permissions
   set allowed = false, updated_at = now()
 where role = 'operations'
   and permission = 'manage_consignees';
