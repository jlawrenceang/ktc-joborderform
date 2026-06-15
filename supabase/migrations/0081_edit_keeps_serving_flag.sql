-- ============================================================
-- 0081 — editing a filed order KEEPS its serving number + flags it (owner, 2026-06-16)
--
-- Supersedes 0079's "edit → back of line". New decision: a customer EDIT of a
-- `submitted` order **keeps its place in the queue** (don't punish a typo fix),
-- but is FLAGGED so KTC re-reviews the change. The serving number is the
-- physical *service* line position; re-review is a flag, not a demotion.
--
--   * held draft   → no number yet; nothing to flag
--   * submitted    → keep number; stamp last_customer_edit_at (the "edited after
--                    filing" marker the admin queue badges)
--   * cancel/reject/suspend → number vacated (unchanged, other migrations)
--
-- Pair with the app's review-before-submit + edit-confirmation prompts.
-- ============================================================

alter table public.job_orders add column if not exists last_customer_edit_at timestamptz;

create or replace function public.update_job_order(
  p_id            uuid,
  p_consignee_id  uuid,
  p_entry_number  text,
  p_vessel_visit  text,
  p_vessel_name   text,
  p_voyage_number text,
  p_lines         jsonb
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_row   public.job_orders%rowtype;
  v_count int := 0;
  e       jsonb;
begin
  select * into v_row from public.job_orders
    where id = p_id and customer_id = public.current_broker_id() for update;
  if not found then raise exception 'Job order not found.'; end if;

  if v_row.status not in ('held', 'submitted') then
    raise exception 'This order can''t be edited anymore — KTC has accepted it. Reply on an on-hold order, or contact KTC admin.';
  end if;

  if p_consignee_id is null then
    raise exception 'Select a consignee.' using errcode = 'check_violation';
  end if;
  if not exists (select 1 from public.consignees where id = p_consignee_id) then
    raise exception 'Consignee not found.';
  end if;
  if length(coalesce(trim(p_entry_number), '')) = 0 then
    raise exception 'Enter the Entry Number (C-…).' using errcode = 'check_violation';
  end if;
  if coalesce(nullif(trim(p_vessel_name), ''), '') = ''
     or coalesce(nullif(trim(p_voyage_number), ''), '') = '' then
    raise exception 'Enter the vessel name and voyage number.' using errcode = 'check_violation';
  end if;

  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    if length(coalesce(trim(e->>'container_number'), '')) > 0 then v_count := v_count + 1; end if;
  end loop;
  if v_count = 0 then
    raise exception 'Add at least one container.' using errcode = 'check_violation';
  end if;

  update public.job_orders
  set consignee_id  = p_consignee_id,
      entry_number  = upper(trim(p_entry_number)),
      vessel_visit  = nullif(trim(p_vessel_visit), ''),
      vessel_name   = upper(trim(p_vessel_name)),
      voyage_number = upper(trim(p_voyage_number)),
      -- "edited after filing" marker — only meaningful once it's been filed.
      last_customer_edit_at = case when v_row.status = 'submitted' then now() else last_customer_edit_at end
  where id = p_id;

  -- Replace the container lines. The line-insert trigger re-runs
  -- assign_serving_numbers, but the order's existing active number(s) are still
  -- present, so it KEEPS its place in the queue (no vacate/reassign here).
  delete from public.job_order_lines where job_order_id = p_id;
  insert into public.job_order_lines (job_order_id, container_number, service_request)
  select p_id, upper(trim(j->>'container_number')), j->>'service_request'
  from jsonb_array_elements(p_lines) j
  where length(coalesce(trim(j->>'container_number'), '')) > 0;

  insert into public.job_order_events (job_order_id, event, actor, detail)
  values (p_id, 'edited', auth.uid(),
          jsonb_build_object('by', 'customer', 'after_filing', v_row.status = 'submitted'));
end;
$$;
revoke all on function public.update_job_order(uuid, uuid, text, text, text, text, jsonb) from public, anon;
grant execute on function public.update_job_order(uuid, uuid, text, text, text, text, jsonb) to authenticated;
