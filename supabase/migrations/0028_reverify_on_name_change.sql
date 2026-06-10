-- ============================================================
-- 0028 — let an APPROVED customer trigger re-verification by changing their
-- legal full name (from the new "My Account" page).
--
-- The full name is what an admin verified against the customer's valid ID, and
-- per the DPA that ID is DELETED on approval. So a silent post-approval rename
-- would leave a name with no ID to check against. Instead, changing the legal
-- name sends the account back to 'pending' so they re-upload an ID and an admin
-- re-verifies the new name.
--
-- The protected-fields guard already permits one self-status-change
-- (rejected -> pending, resubmission). This adds a second: approved -> pending
-- (re-verification). Every other self-status-change stays blocked (no
-- self-approve, no un-suspend, etc.).
-- ============================================================

create or replace function public.guard_broker_protected_fields()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    return new;  -- trusted server / SQL context
  end if;

  if old.is_owner then
    new.is_owner   := old.is_owner;
    new.is_admin   := old.is_admin;
    new.status     := old.status;
    new.decided_at := old.decided_at;
  end if;

  if not public.is_admin() then
    new.is_owner := old.is_owner;
    new.is_admin := old.is_admin;
    -- permitted self-initiated status changes:
    --   rejected -> pending  (resubmit after rejection)
    --   approved -> pending  (re-verify after a legal-name change)
    -- block every other self-status-change.
    if not (old.status in ('rejected', 'approved') and new.status = 'pending') then
      new.status     := old.status;
      new.decided_at := old.decided_at;
    end if;
  end if;

  new.is_owner := old.is_owner;  -- owner grant/revoke is server-only
  return new;
end;
$$;
