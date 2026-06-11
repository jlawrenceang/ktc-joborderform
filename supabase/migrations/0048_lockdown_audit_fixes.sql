-- ============================================================
-- 0048 — self-audit fixes (2026-06-12 security review).
--
-- Findings from a live privilege audit:
--   1. public._migrations (the migration tracker) had NO RLS — Supabase's
--      default grants would let any anon-key holder read AND write it.
--      RLS on + grants revoked = server-only (the migration runner connects
--      as postgres, which bypasses both).
--   2. Several SECURITY DEFINER functions were executable by anon via the
--      default PUBLIC grant: maintenance functions (expire_unverified_brokers)
--      and RLS helpers. Helpers keep an explicit authenticated grant (RLS
--      policies evaluate them as the querying role) and lose PUBLIC/anon;
--      trigger functions and maintenance functions lose everything (triggers
--      fire under the table owner; cron runs as postgres).
-- ============================================================

-- 1) migration tracker: server-only
alter table public._migrations enable row level security;
revoke all on table public._migrations from public, anon, authenticated;

-- 2a) RLS helper functions: authenticated only (grant BEFORE revoking PUBLIC,
--     since their current access rides on the default PUBLIC grant)
grant execute on function public.broker_is_approved() to authenticated;
grant execute on function public.broker_is_pending() to authenticated;
grant execute on function public.current_broker_id() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.jo_all_services_done(uuid) to authenticated;
revoke execute on function public.broker_is_approved() from public, anon;
revoke execute on function public.broker_is_pending() from public, anon;
revoke execute on function public.current_broker_id() from public, anon;
revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.jo_all_services_done(uuid) from public, anon;

-- 2b) maintenance: cron/postgres only
revoke all on function public.expire_unverified_brokers() from public, anon, authenticated;

-- 2c) trigger functions: nobody calls these directly (trigger firing doesn't
--     check the invoker's EXECUTE privilege)
do $$
declare f text;
begin
  foreach f in array array[
    'audit_job_orders', 'audit_role_gate_change', 'enforce_order_caps',
    'guard_broker_protected_fields', 'handle_new_user', 'release_held_job_orders',
    'send_broker_approved_email', 'send_job_order_status_email',
    'serving_numbers_on_line', 'serving_numbers_on_status', 'stamp_completed_at',
    'sync_completions_on_complete', 'sync_email_confirmed'
  ] loop
    begin
      execute format('revoke all on function public.%I() from public, anon, authenticated', f);
    exception when undefined_function then
      raise notice 'skip % (not found)', f;
    end;
  end loop;
end $$;
