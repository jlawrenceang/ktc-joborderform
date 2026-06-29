-- ============================================================
-- 0196 — Lock down disposable_email_domains (security audit #1)
--
-- BUG: disposable_email_domains (0164) is the ONLY RPC-only table that never got
-- the standard lockdown — it has NO row-level security and authenticated/anon
-- still hold Supabase's default ALL grants. So any logged-in user (even a pending
-- or rejected customer) — or possibly the anon key in the frontend bundle — can
-- hit PostgREST directly:
--   DELETE FROM disposable_email_domains   → defeats the disposable-email signup
--                                             control (handle_new_user, 0164)
--   INSERT (domain) VALUES ('gmail.com'),… → poisons it so handle_new_user rejects
--                                             all new legit signups (onboarding DoS)
-- Every other RPC-only table does BOTH enable-RLS + revoke (see _migrations 0048,
-- active_sessions 0054, vessel_requests 0068). This brings it in line.
--
-- handle_new_user + list/add/remove_disposable_domains (0190) are SECURITY DEFINER
-- and run as the function owner, so they bypass RLS — the table becomes truly
-- RPC-only (no SELECT/write policy needed), exactly as 0190's comment intends.
-- ============================================================

alter table public.disposable_email_domains enable row level security;
revoke all on table public.disposable_email_domains from public, anon, authenticated;
