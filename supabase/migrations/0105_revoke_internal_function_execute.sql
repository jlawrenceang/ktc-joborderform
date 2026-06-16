-- ============================================================
-- 0105 — lock down internal SECURITY DEFINER functions (owner, 2026-06-16)
--
-- Backend audit finding (medium ×2, same root cause). Supabase's default ACL
-- grants EXECUTE to `authenticated` on EVERY function in schema public
-- (pg_default_acl, defaclobjtype 'f'). Migrations that only did
-- `revoke ... from public, anon` therefore left the function callable by any
-- logged-in user. Two internal, NON-trigger writers had no in-body auth check
-- and were thus directly invokable via supabase.rpc(...):
--   * notify_staff(...)          — bare insert into staff_notifications; a
--                                  customer could forge/flood any staff desk.
--   * assign_serving_numbers(..) — mutates the shared weekly queue sequence;
--                                  a customer could burn/inflate serving numbers
--                                  or number orders they don't own.
-- Both are only ever called from SECURITY DEFINER triggers, which run as the
-- function owner regardless of the caller's grant — so revoking `authenticated`
-- does NOT break the legitimate paths. Neither is referenced anywhere in src/.
--
-- We also sweep EXECUTE from `authenticated`/`anon` on every SECURITY DEFINER
-- *trigger* function in public as defense-in-depth: trigger functions are never
-- meant to be called directly (they reference TG_OP/NEW and fire via triggers as
-- the owner), so revoking the client grant is always safe and never breaks a
-- trigger. Legitimate client RPCs (file_job_order, add_supplement,
-- staff_transition_order, …) are regular functions with their own guards and are
-- left untouched.
-- ============================================================

-- 1. The two confirmed unguarded internal writers.
revoke execute on function public.notify_staff(text, text, text, uuid, uuid) from authenticated, anon;
revoke execute on function public.assign_serving_numbers(uuid) from authenticated, anon;

-- 2. Defense-in-depth: every SECURITY DEFINER trigger function in public.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure::text as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.prorettype = 'pg_catalog.trigger'::regtype
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  loop
    execute format('revoke execute on function %s from authenticated, anon', f.sig);
  end loop;
end $$;
