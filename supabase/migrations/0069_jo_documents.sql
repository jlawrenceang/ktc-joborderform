-- ============================================================
-- 0069 — supporting documents + notes on a Job Order (owner, 2026-06-15)
--
-- Customers can attach OPTIONAL supporting info to any of their ACTIVE orders
-- (held / submitted / processing / on_hold) at any time — a note and/or a
-- document (packing list, proforma, corrected entry, etc.) — to help KTC
-- verify and process the order faster. Each entry is a note, a file, or both.
-- Staff (anyone who can view job orders) can read them; ops reviews them while
-- processing.
--
-- Mirrors the payment-slips / valid-ids storage pattern: a private per-user
-- bucket folder, writes only through the SECURITY DEFINER RPC.
-- ============================================================

-- 1) Private bucket — per-user folder (foldername[1] = auth.uid()).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('jo-documents', 'jo-documents', false, 5242880,
   array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif','application/pdf'])
on conflict (id) do nothing;

drop policy if exists "user uploads own jo document" on storage.objects;
create policy "user uploads own jo document" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'jo-documents' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "user reads own jo document" on storage.objects;
create policy "user reads own jo document" on storage.objects
  for select to authenticated
  using (bucket_id = 'jo-documents' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "staff reads jo documents" on storage.objects;
create policy "staff reads jo documents" on storage.objects
  for select to authenticated
  using (bucket_id = 'jo-documents' and public.has_permission('view_job_orders'));

-- 2) Record table — one row per supporting submission (note and/or file).
create table if not exists public.job_order_documents (
  id            uuid primary key default gen_random_uuid(),
  job_order_id  uuid not null references public.job_orders(id) on delete cascade,
  path          text,           -- storage object path (null = note-only)
  filename      text,           -- original display name
  note          text,           -- optional note to KTC
  uploaded_by   uuid references public.customers(id),
  created_at    timestamptz not null default now()
);
create index if not exists jo_documents_order_idx on public.job_order_documents (job_order_id);

alter table public.job_order_documents enable row level security;

-- Customer reads supporting info on their OWN orders; staff read all. Writes go
-- only through add_jo_support (no insert/update/delete policy).
drop policy if exists "read jo documents" on public.job_order_documents;
create policy "read jo documents" on public.job_order_documents
  for select to authenticated using (
    public.has_permission('view_job_orders')
    or exists (select 1 from public.job_orders jo
               where jo.id = job_order_id and jo.customer_id = public.current_broker_id())
  );

-- 3) Add a supporting entry (note and/or file) to an own ACTIVE order.
create or replace function public.add_jo_support(
  p_jo uuid, p_path text default null, p_filename text default null, p_note text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if coalesce(trim(p_path), '') = '' and coalesce(trim(p_note), '') = '' then
    raise exception 'Add a note or attach a document.';
  end if;
  if not exists (
    select 1 from public.job_orders
    where id = p_jo and customer_id = public.current_broker_id()
      and status in ('held','submitted','processing','on_hold')
  ) then
    raise exception 'You can only add supporting info to your own active job orders.';
  end if;
  insert into public.job_order_documents (job_order_id, path, filename, note, uploaded_by)
  values (p_jo, nullif(trim(p_path), ''), nullif(trim(p_filename), ''), nullif(trim(p_note), ''), public.current_broker_id());
end;
$$;
revoke all on function public.add_jo_support(uuid, text, text, text) from public, anon;
grant execute on function public.add_jo_support(uuid, text, text, text) to authenticated;
