-- 0168: sync resubmit_consignee with the full CIS (matches request_consignee, 0166).
-- A customer whose consignee was flagged "needs info" can now also add/edit the
-- registered/customer name, 2nd address line, tel, mobile, and email — not just the
-- original five fields — so "please add more information" can cover any CIS field.
-- The old 6-arg overload is dropped first to avoid a call-ambiguity error.
drop function if exists public.resubmit_consignee(uuid, text, text, text, text, text);

create or replace function public.resubmit_consignee(
  p_id uuid,
  p_name text default null, p_address text default null, p_tin text default null,
  p_doc_2303 text default null, p_doc_2307 text default null,
  p_customer_name text default null, p_address2 text default null,
  p_tel text default null, p_mobile text default null, p_email text default null
)
returns void language plpgsql security definer set search_path = public as $$
declare v_cust uuid := public.current_broker_id();
begin
  if v_cust is null then raise exception 'No customer profile found.'; end if;
  update public.consignees
     set name          = coalesce(nullif(trim(coalesce(p_name, '')), ''), name),
         address       = coalesce(nullif(trim(coalesce(p_address, '')), ''), address),
         tin           = coalesce(nullif(trim(coalesce(p_tin, '')), ''), tin),
         doc_2303_path = coalesce(nullif(trim(coalesce(p_doc_2303, '')), ''), doc_2303_path),
         doc_2307_path = coalesce(nullif(trim(coalesce(p_doc_2307, '')), ''), doc_2307_path),
         customer_name = coalesce(nullif(trim(coalesce(p_customer_name, '')), ''), customer_name),
         address2      = coalesce(nullif(trim(coalesce(p_address2, '')), ''), address2),
         tel           = coalesce(nullif(trim(coalesce(p_tel, '')), ''), tel),
         mobile        = coalesce(nullif(trim(coalesce(p_mobile, '')), ''), mobile),
         email         = coalesce(nullif(trim(coalesce(p_email, '')), ''), email),
         status = 'pending', note = null, requested_at = now()
   where id = p_id and requested_by = v_cust and status = 'needs_info';
  if not found then raise exception 'Request not found or not editable.'; end if;
end;
$$;
revoke all on function public.resubmit_consignee(uuid, text, text, text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.resubmit_consignee(uuid, text, text, text, text, text, text, text, text, text, text) to authenticated;

notify pgrst, 'reload schema';
