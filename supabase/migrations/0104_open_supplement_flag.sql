-- ============================================================
-- 0104 — surface "under review" orders in the customer's Needs-action view
--        (owner, 2026-06-16)
--
-- An order with an unpaid additional charge (supplement) is "under review" and
-- needs the customer to pay. The customer already gets a bell notification + an
-- ⏳ chip, but the server-side "Needs action" filter in My Job Orders couldn't
-- see it: "has an outstanding supplement" is a cross-table condition that
-- PostgREST can't express in a parent .or() filter. So we denormalize it into a
-- queryable boolean on job_orders, kept in sync by a trigger on jo_supplements.
-- ============================================================

alter table public.job_orders
  add column if not exists has_open_supplement boolean not null default false;

-- Backfill from existing supplements (outstanding = not yet confirmed).
update public.job_orders jo
   set has_open_supplement = exists (
     select 1 from public.jo_supplements s
     where s.job_order_id = jo.id and s.payment_status <> 'confirmed'
   )
 where exists (select 1 from public.jo_supplements s where s.job_order_id = jo.id);

-- Recompute the flag for one order from its supplements. Touches only
-- has_open_supplement, so the status / payment two-gate triggers don't fire.
create or replace function public.sync_open_supplement()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_jo uuid := coalesce(new.job_order_id, old.job_order_id);
begin
  update public.job_orders jo
     set has_open_supplement = exists (
       select 1 from public.jo_supplements s
       where s.job_order_id = v_jo and s.payment_status <> 'confirmed'
     )
   where jo.id = v_jo
     and jo.has_open_supplement is distinct from exists (
       select 1 from public.jo_supplements s
       where s.job_order_id = v_jo and s.payment_status <> 'confirmed'
     );
  return null;
end;
$$;

-- INSERT/UPDATE only — supplements are never deleted except by JO cascade
-- (the flag is moot once the order is gone), which sidesteps cascade ordering.
drop trigger if exists trg_sync_open_supplement on public.jo_supplements;
create trigger trg_sync_open_supplement
  after insert or update on public.jo_supplements
  for each row execute function public.sync_open_supplement();
