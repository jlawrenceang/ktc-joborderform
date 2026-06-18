-- ============================================================
-- 0119 — staff access is email-invite-only (owner, 2026-06-18)
--
-- Staff are now granted ONLY through the admin-create-staff edge function
-- (GoTrue inviteUserByEmail -> promote_new_staff). Lock down the other paths so
-- the invite is the single way a role is granted ("nothing else"):
--   * revoke create_staff (the legacy hand-written-auth.users RPC) from every
--     client role — it can no longer be called via supabase.rpc().
--   * the "grant admin to an existing email" UI is removed in the same change.
--   * promote_new_staff (0118) stays — owner-gated, used by the invite edge fn.
--
-- create_staff is left DEFINED (not dropped) purely to avoid breaking any
-- dependency; with EXECUTE revoked it is inert.
-- ============================================================

revoke all on function public.create_staff(text, text, text, text) from public, anon, authenticated;
