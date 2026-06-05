-- ============================================================
-- 0009 — consignee accreditation details: address, TIN, 2303 document.
-- A consignee needs address + TIN + an attached 2303 before it can be
-- approved. Existing approved rows (the imported master list) are grandfathered.
-- ============================================================

alter table public.consignees add column if not exists address       text;
alter table public.consignees add column if not exists tin           text;
alter table public.consignees add column if not exists doc_2303_path text;

-- private bucket for 2303 documents — admins only
insert into storage.buckets (id, name, public)
values ('consignee-docs', 'consignee-docs', false)
on conflict (id) do nothing;

drop policy if exists "admin manages consignee docs" on storage.objects;
create policy "admin manages consignee docs" on storage.objects
  for all to authenticated
  using (bucket_id = 'consignee-docs' and public.is_admin())
  with check (bucket_id = 'consignee-docs' and public.is_admin());

-- require address + TIN + 2303 to approve (grandfather already-approved rows)
create or replace function public.guard_consignee_approval()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.status = 'approved'
     and (coalesce(new.address, '') = '' or coalesce(new.tin, '') = '' or coalesce(new.doc_2303_path, '') = '') then
    if tg_op = 'UPDATE' and old.status = 'approved' then
      return new;  -- already approved before these rules -> leave it be
    end if;
    raise exception 'Consignee requires address, TIN, and an attached 2303 document before approval';
  end if;
  return new;
end;
$$;

drop trigger if exists consignees_approval_guard on public.consignees;
create trigger consignees_approval_guard before insert or update on public.consignees
  for each row execute function public.guard_consignee_approval();
