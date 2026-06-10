-- ============================================================
-- 0023 — change the job-order series format from 'X-######' to 'JO-#####'
-- so the number reads as a JO. Assigned by ensure_jo_number() on the first
-- transition to a live status. (No existing job orders to migrate.)
-- ============================================================

create or replace function public.ensure_jo_number()
returns trigger language plpgsql as $$
begin
  if new.jo_number is null and new.status in ('submitted','processing','completed') then
    new.jo_number := 'JO-' || lpad(nextval('public.jo_number_seq')::text, 5, '0');
  end if;
  return new;
end;
$$;
