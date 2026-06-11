-- ============================================================
-- 0040 — gap fixes G1 + G2 + G6 (2026-06-11).
--
-- G1  PER-SERVICE COMPLETION. One JO status meant the checker confirming
--     X-ray completed the WHOLE order even with OOG/DEA lines still pending.
--     Now each service line completes individually (service_completions);
--     the JO flips to 'completed' only when EVERY line it needs is done.
--     record_xray stays as a thin wrapper (checker app unchanged); an admin
--     force-complete (direct status set) syncs the per-line rows so the two
--     views can't disagree.
--
-- G2  WEEKLY CARRY-OVER. Open orders crossing the Monday reset kept last
--     week's number — valid but invisible on the new board. Policy chosen:
--     carry-overs KEEP PRIORITY — a Monday 00:15 PH cron re-queues them at
--     the FRONT of the new week's line, in their old order (old numbers are
--     vacated/burned).
--
-- G6  AUDIT TRAIL. job_order_events: who did what, when — filed, status
--     changes, per-service completions, payment events, invoice recorded,
--     archived. Written only by triggers/definer functions; readable by
--     staff (view_job_orders gate). actor null = system (cron/trigger
--     without a session).
-- ============================================================

-- ---------- G6: events table first (the other fixes log into it) ----------
create table if not exists public.job_order_events (
  id            uuid primary key default gen_random_uuid(),
  job_order_id  uuid not null references public.job_orders(id) on delete cascade,
  actor         uuid,            -- auth.uid(); null = system
  event         text not null,
  detail        jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);
create index if not exists job_order_events_jo_idx on public.job_order_events (job_order_id, created_at);
alter table public.job_order_events enable row level security;

drop policy if exists "staff read job order events" on public.job_order_events;
create policy "staff read job order events" on public.job_order_events
  for select to authenticated using (public.has_permission('view_job_orders'));
-- no INSERT/UPDATE policies: only definer functions/triggers write

create or replace function public.log_jo_event(p_jo uuid, p_event text, p_detail jsonb default '{}'::jsonb)
returns void language sql security definer set search_path = public as $$
  insert into public.job_order_events (job_order_id, actor, event, detail)
  values (p_jo, auth.uid(), p_event, coalesce(p_detail, '{}'::jsonb));
$$;

create or replace function public.audit_job_orders()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_jo_event(new.id, 'filed', jsonb_build_object('status', new.status));
    return new;
  end if;
  if old.status is distinct from new.status then
    perform public.log_jo_event(new.id, 'status_changed',
      jsonb_build_object('from', old.status, 'to', new.status, 'note', new.admin_note));
  end if;
  if old.payment_status is distinct from new.payment_status then
    perform public.log_jo_event(new.id, 'payment_' || new.payment_status,
      jsonb_build_object('note', new.payment_note));
  end if;
  if old.service_invoice_no is distinct from new.service_invoice_no and new.service_invoice_no is not null then
    perform public.log_jo_event(new.id, 'invoice_recorded', jsonb_build_object('si', new.service_invoice_no));
  end if;
  if old.archived_at is null and new.archived_at is not null then
    perform public.log_jo_event(new.id, 'archived', '{}'::jsonb);
  end if;
  return new;
end;
$$;
drop trigger if exists job_orders_audit on public.job_orders;
create trigger job_orders_audit after insert or update on public.job_orders
  for each row execute function public.audit_job_orders();

revoke all on function public.log_jo_event(uuid, text, jsonb) from public, anon, authenticated;

-- ---------- G1: per-service completion ----------
create table if not exists public.service_completions (
  job_order_id  uuid not null references public.job_orders(id) on delete cascade,
  service_line  text not null check (service_line in ('xray','dea','oog','other')),
  completed_at  timestamptz not null default now(),
  completed_by  uuid,
  primary key (job_order_id, service_line)
);
alter table public.service_completions enable row level security;

drop policy if exists "read service completions" on public.service_completions;
create policy "read service completions" on public.service_completions
  for select to authenticated using (
    public.has_permission('view_job_orders')
    or exists (select 1 from public.job_orders jo
               where jo.id = job_order_id and jo.customer_id = public.current_broker_id())
  );

-- All service lines this JO needs are done?
create or replace function public.jo_all_services_done(p_jo uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from (
      select distinct public.service_line_of(service_request) as line
      from public.job_order_lines where job_order_id = p_jo
    ) needed
    where not exists (
      select 1 from public.service_completions c
      where c.job_order_id = p_jo and c.service_line = needed.line
    )
  );
$$;

-- Mark ONE service line done. X-ray: checker (confirm_xray) or admin;
-- DEA/OOG: admin (process_job_orders). Completes the JO when all lines done,
-- otherwise moves submitted -> processing (work has visibly started).
create or replace function public.record_service_done(p_id uuid, p_line text, p_performed_at timestamptz default now())
returns void language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  if p_line = 'xray' then
    if not (public.has_permission('confirm_xray') or public.has_permission('process_job_orders')) then
      raise exception 'You don''t have permission to confirm X-ray completion.';
    end if;
  else
    if not public.has_permission('process_job_orders') then
      raise exception 'You don''t have permission to mark services done.';
    end if;
  end if;
  if p_line not in ('xray','dea','oog','other') then
    raise exception 'Unknown service line %', p_line;
  end if;
  select status into v_status from public.job_orders where id = p_id for update;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status not in ('submitted','processing','on_hold') then
    raise exception 'This order is % — only open orders can be confirmed.', v_status;
  end if;

  insert into public.service_completions (job_order_id, service_line, completed_at, completed_by)
  values (p_id, p_line, coalesce(p_performed_at, now()), auth.uid())
  on conflict (job_order_id, service_line) do nothing;
  perform public.log_jo_event(p_id, 'service_done', jsonb_build_object('line', p_line));

  if p_line = 'xray' then
    update public.job_orders set xray_performed_at = coalesce(xray_performed_at, p_performed_at, now())
      where id = p_id;
  end if;

  if public.jo_all_services_done(p_id) then
    update public.job_orders set status = 'completed' where id = p_id;
  elsif v_status = 'submitted' then
    update public.job_orders set status = 'processing' where id = p_id;
  end if;
end;
$$;

-- Back-compat wrapper — the checker app keeps calling record_xray.
create or replace function public.record_xray(p_id uuid, p_performed_at timestamptz default now())
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.record_service_done(p_id, 'xray', p_performed_at);
end;
$$;

-- Admin force-complete (direct status set) syncs the per-line rows.
create or replace function public.sync_completions_on_complete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'completed' and old.status is distinct from new.status then
    insert into public.service_completions (job_order_id, service_line, completed_at, completed_by)
    select new.id, t.line, now(), auth.uid()
    from (select distinct public.service_line_of(service_request) as line
          from public.job_order_lines where job_order_id = new.id) t
    on conflict (job_order_id, service_line) do nothing;
  end if;
  return new;
end;
$$;
drop trigger if exists job_orders_sync_completions on public.job_orders;
create trigger job_orders_sync_completions after update of status on public.job_orders
  for each row execute function public.sync_completions_on_complete();

-- Backfill: existing completed orders count as all-services-done.
insert into public.service_completions (job_order_id, service_line, completed_at)
select jo.id, t.line, coalesce(jo.completed_at, jo.created_at)
from public.job_orders jo
cross join lateral (select distinct public.service_line_of(l.service_request) as line
                    from public.job_order_lines l where l.job_order_id = jo.id) t
where jo.status = 'completed'
on conflict (job_order_id, service_line) do nothing;

revoke all on function public.record_service_done(uuid, text, timestamptz) from public, anon;
grant execute on function public.record_service_done(uuid, text, timestamptz) to authenticated;

-- ---------- G2: weekly carry-over (keep priority) ----------
-- Re-queue still-open orders holding a PREVIOUS week's number at the FRONT of
-- the new week's line, preserving their old order. Old numbers are burned.
create or replace function public.requeue_carryovers()
returns int language plpgsql security definer set search_path = public as $$
declare
  v_week date := public.serving_week();
  v_next int;
  v_count int := 0;
  r record;
begin
  if auth.uid() is not null and not public.has_permission('process_job_orders') then
    raise exception 'You don''t have permission to re-queue carry-overs.';
  end if;
  for r in
    select s.id, s.job_order_id, s.service_line
    from public.serving_numbers s
    join public.job_orders jo on jo.id = s.job_order_id
    where s.vacated_at is null
      and s.week_start < v_week
      and jo.status in ('submitted','processing','on_hold')
    order by s.service_line, s.week_start, s.serving_no
  loop
    perform pg_advisory_xact_lock(hashtext('serving:' || r.service_line || ':' || v_week::text));
    select coalesce(max(serving_no), 0) + 1 into v_next
      from public.serving_numbers
      where service_line = r.service_line and week_start = v_week;
    update public.serving_numbers set vacated_at = now() where id = r.id;
    insert into public.serving_numbers (job_order_id, service_line, week_start, serving_no)
      values (r.job_order_id, r.service_line, v_week, v_next);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.requeue_carryovers() from public, anon;
grant execute on function public.requeue_carryovers() to authenticated;

-- Monday 00:15 Asia/Manila = Sunday 16:15 UTC — runs BEFORE anyone files,
-- so carry-overs take numbers 1..k at the front of the fresh week.
do $$
begin
  perform cron.unschedule('requeue-carryovers-weekly');
exception when others then null;
end $$;
select cron.schedule(
  'requeue-carryovers-weekly',
  '15 16 * * 0',
  $job$ select public.requeue_carryovers(); $job$
);
