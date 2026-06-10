-- ============================================================
-- 0026 — let a REJECTED customer resubmit for review.
--
-- (1) The protected-fields guard now permits exactly one self-initiated status
--     change: rejected -> pending (resubmission). Every other self-status-change
--     stays blocked (no self-approve, etc.).
-- (2) Rejection is recoverable, so held orders are kept on 'rejected' (they
--     release when the customer is later approved). Only 'suspended' (terminal)
--     cancels held orders.
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
    -- allow a customer to resubmit a rejected account (rejected -> pending);
    -- block every other self-initiated status change.
    if not (old.status = 'rejected' and new.status = 'pending') then
      new.status     := old.status;
      new.decided_at := old.decided_at;
    end if;
  end if;

  new.is_owner := old.is_owner;  -- owner grant/revoke is server-only
  return new;
end;
$$;

create or replace function public.release_held_job_orders()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status is distinct from new.status then
    if new.status = 'approved' then
      update public.job_orders set status = 'submitted'
        where customer_id = new.id and status = 'held';
    elsif new.status = 'suspended' then
      -- terminal: cancel held orders. ('rejected' is recoverable, so keep them.)
      update public.job_orders set status = 'cancelled'
        where customer_id = new.id and status = 'held';
    end if;
  end if;
  return new;
end;
$$;
