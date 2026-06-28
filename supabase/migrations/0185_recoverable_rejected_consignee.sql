-- ============================================================
-- 0185 — recoverable rejected consignee requests (audit T1-04, owner 2026-06-28)
--
-- 0163's "approved consignees readable" policy let a requester see their own
-- pending/needs_info rows but NOT rejected ones, so a rejected consignee request
-- vanished from My Requests; the global unique index on the name then blocked
-- re-requesting it, and (not being approved) it wasn't in the picker either — the
-- name was bricked with no path forward. Fix: (1) let the requester SEE their own
-- rejected rows, and (2) let resubmit_consignee reset a rejected row back to pending
-- (same row → no unique-violation), exactly like needs_info. Staff branches unchanged.
-- ============================================================

-- 1) Requester can now also see their own REJECTED requests (adds 'rejected'; the two
--    staff branches and the approved-customer branch are recreated from 0163 verbatim).
drop policy if exists "approved consignees readable" on public.consignees;
create policy "approved consignees readable" on public.consignees
  for select to authenticated using (
    public.is_admin()
    or public.has_permission('review_consignee_requests')
    or (
      public.broker_is_approved() and (
        status = 'approved'
        or (requested_by = public.current_broker_id() and status in ('pending', 'needs_info', 'rejected'))
      )
    )
  );

-- 2) resubmit_consignee now also resets a REJECTED row → pending (recreate the 0168 body
--    verbatim; only the WHERE status predicate changes: needs_info -> needs_info|rejected).
create or replace function public.resubmit_consignee(
  p_id uuid,
  p_name text default null, p_address text default null, p_tin text default null,
  p_doc_2303 text default null, p_doc_2307 text default null,
  p_customer_name text default null, p_address2 text default null,
  p_tel text default null, p_mobile text default null, p_email text default null
)
returns void language plpgsql security definer set search_path = public as $$
declare v_cust uuid := public.current_broker_id(); v_hit boolean;
begin
  if v_cust is null then raise exception 'No customer profile found.'; end if;
  begin
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
     where id = p_id and requested_by = v_cust and status in ('needs_info', 'rejected');
    v_hit := found;
  exception when unique_violation then
    raise exception 'A consignee with that name already exists — search for it in the list.'
      using errcode = 'check_violation';
  end;
  if not v_hit then raise exception 'Request not found or not editable.'; end if;
end;
$$;
revoke all on function public.resubmit_consignee(uuid, text, text, text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.resubmit_consignee(uuid, text, text, text, text, text, text, text, text, text, text) to authenticated;
