-- ============================================================
-- 0243 — tighten consignees_public to authenticated-only (fix for a 0241 regression)
--
-- 0241 created the `consignees_public` view and granted SELECT to `authenticated`. But Supabase
-- ships ALTER DEFAULT PRIVILEGES on the `public` schema that auto-grant SELECT to `anon` (and
-- authenticated/service_role) on every new view — so the view ended up readable by UNAUTHENTICATED
-- anon-key requests, exposing the entire consignee directory (all id/code/name) publicly. The base
-- `consignees` table was never anon-readable; this was an unintended regression.
--
-- The view exists only to back the broker/staff order-display embeds, all of which are authenticated.
-- Revoke anon. (Poka-yoke / PITFALLS: any new public-schema view inherits Supabase's default anon
-- grant — explicitly REVOKE anon unless the object is meant to be public.)
-- ============================================================

revoke select on public.consignees_public from anon;

notify pgrst, 'reload schema';
