-- ============================================================
-- 0089 — public Job-Order verification (QR target) (owner, 2026-06-16)
--
-- The completed slip carries a QR pointing at /verify/<id>. Scanning it (a
-- terminal guard, BOC, anyone holding the paper) hits this definer RPC, which
-- returns only the MINIMAL, non-sensitive facts needed to confirm the slip is
-- genuine and completed: JO number, status, completion date, consignee, and
-- container count. Keyed on the order's UUID (unguessable; only printed on the
-- slip), granted to anon so it works without a portal login.
--
-- Foundation for a future gate module — a guard scanning the same QR could log
-- gate-in / gate-out (gate_events) from a verify screen.
-- ============================================================

create or replace function public.verify_job_order(p_id uuid)
returns table (jo_number text, status text, completed_at timestamptz, consignee text, containers int)
language sql security definer set search_path = public as $$
  select jo.jo_number,
         jo.status,
         jo.completed_at,
         (select c.code || ' – ' || c.name from public.consignees c where c.id = jo.consignee_id),
         (select count(*)::int from public.job_order_lines l where l.job_order_id = jo.id)
  from public.job_orders jo
  where jo.id = p_id;
$$;

revoke all on function public.verify_job_order(uuid) from public;
grant execute on function public.verify_job_order(uuid) to anon, authenticated;
