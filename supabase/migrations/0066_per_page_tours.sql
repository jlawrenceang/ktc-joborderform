-- ============================================================
-- 0066 — per-PAGE tours (owner, 2026-06-13)
--
-- Instead of one long walkthrough, each page shows its own short tour the
-- first time the account lands on it. Track which page tours an account has
-- seen in an array; mark_tour_seen takes the page key and appends it.
-- (The old boolean tour_seen column is left in place, now unused.)
-- ============================================================

alter table public.customers add column if not exists tours_seen text[] not null default '{}';

drop function if exists public.mark_tour_seen();
create or replace function public.mark_tour_seen(p_page text)
returns void language sql security definer set search_path = public as $$
  update public.customers
     set tours_seen = (select array_agg(distinct e) from unnest(tours_seen || array[p_page]) e)
   where user_id = auth.uid();
$$;
revoke all on function public.mark_tour_seen(text) from public, anon;
grant execute on function public.mark_tour_seen(text) to authenticated;
