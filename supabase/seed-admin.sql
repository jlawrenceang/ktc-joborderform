-- ============================================================
-- Promote user(s) to admin.
-- The person must have SIGNED UP at least once (so their broker row exists),
-- then run this in the SQL Editor with their email.
-- ============================================================

update public.brokers
set is_admin = true
where email = 'REPLACE_WITH_ADMIN_EMAIL';

-- Verify:
-- select email, is_admin from public.brokers order by is_admin desc;
