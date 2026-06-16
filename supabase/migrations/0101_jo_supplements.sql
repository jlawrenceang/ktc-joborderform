-- ============================================================
-- 0101 — JO supplements: lightweight additional-charge lines + under-review
--        (owner, 2026-06-16)
--
-- An order can accrue additional charges after filing (operations "tags" them).
-- Each is a supplement attached to the main JO, numbered JO-<no>-A / -B / -C…,
-- with its own amount + payment slip + confirm. Release/completion now also
-- requires EVERY supplement paid. Adding a charge to an already-completed order
-- bounces it back to "under review" (status -> processing, completed_at cleared)
-- until the new charge is settled — then it auto-completes again. (RPS keeps its
-- existing dedicated flow and also gates release; the two coexist.)
-- ============================================================

create table if not exists public.jo_supplements (
  id                  uuid primary key default gen_random_uuid(),
  job_order_id        uuid not null references public.job_orders(id) on delete cascade,
  suffix              text not null,                 -- A, B, C…
  label               text not null,
  amount              numeric(12,2) not null default 0,
  payment_status      text not null default 'unpaid' check (payment_status in ('unpaid','submitted','confirmed','rejected')),
  payment_proof_path  text,
  payment_submitted_at timestamptz,
  payment_confirmed_at timestamptz,
  payment_note        text,
  created_by          uuid,
  created_at          timestamptz not null default now(),
  unique (job_order_id, suffix)
);
alter table public.jo_supplements enable row level security;

drop policy if exists "read supplements" on public.jo_supplements;
create policy "read supplements" on public.jo_supplements
  for select to authenticated using (
    public.has_permission('view_job_orders')
    or exists (select 1 from public.job_orders jo where jo.id = job_order_id and jo.customer_id = public.current_broker_id())
  );
-- writes via the RPCs below only.

-- ---------- completion gate now includes supplements ----------
create or replace function public.jo_ready_to_complete(p_jo uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.jo_all_services_done(p_jo)
     and (select jo.payment_status = 'confirmed'
                 and (jo.rps_status <> 'needed' or jo.rps_payment_status = 'confirmed')
          from public.job_orders jo where jo.id = p_jo)
     and not exists (select 1 from public.jo_supplements s
                     where s.job_order_id = p_jo and s.payment_status <> 'confirmed');
$$;

create or replace function public.enforce_two_gate_complete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    if not (public.jo_all_services_done(new.id)
            and new.payment_status = 'confirmed'
            and (new.rps_status <> 'needed' or new.rps_payment_status = 'confirmed')
            and not exists (select 1 from public.jo_supplements s
                            where s.job_order_id = new.id and s.payment_status <> 'confirmed')) then
      raise exception 'Cannot complete — services, base payment, RPS, and all additional charges must be cleared.'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

-- ---------- add a supplement (operations / admin tag an additional charge) ----------
create or replace function public.add_supplement(p_jo uuid, p_label text, p_amount numeric default 0)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_n int; v_suffix text; v_id uuid; v_status text;
begin
  if not public.has_permission('process_job_orders') then
    raise exception 'You don''t have permission to add a charge.';
  end if;
  if length(coalesce(trim(p_label), '')) = 0 then raise exception 'Enter a charge label.'; end if;
  select status into v_status from public.job_orders where id = p_jo for update;
  if not found then raise exception 'Job order not found.'; end if;
  if v_status in ('cancelled','rejected','held') then
    raise exception 'Can''t add a charge to a % order.', v_status;
  end if;
  select count(*) into v_n from public.jo_supplements where job_order_id = p_jo;
  if v_n >= 26 then raise exception 'Too many supplements on this order.'; end if;
  v_suffix := chr(65 + v_n);
  insert into public.jo_supplements (job_order_id, suffix, label, amount, created_by)
    values (p_jo, v_suffix, trim(p_label), coalesce(p_amount, 0), auth.uid())
    returning id into v_id;

  -- A new unpaid charge un-completes a finished order: back to "under review".
  if v_status = 'completed' then
    update public.job_orders set status = 'processing', completed_at = null where id = p_jo;
  end if;

  perform public.log_jo_event(p_jo, 'supplement_added',
    jsonb_build_object('suffix', v_suffix, 'label', trim(p_label), 'amount', coalesce(p_amount, 0)));
  insert into public.notifications (customer_id, job_order_id, kind, title)
    select customer_id, p_jo, 'rps',
           'An additional charge (' || trim(p_label) || ') was added to ' ||
           coalesce(jo_number, 'your job order') || ' — please settle it to proceed.'
    from public.job_orders where id = p_jo;
  return v_id;
end;
$$;
revoke all on function public.add_supplement(uuid, text, numeric) from public, anon;
grant execute on function public.add_supplement(uuid, text, numeric) to authenticated;

-- ---------- customer submits a supplement payment proof ----------
create or replace function public.submit_supplement_proof(p_supp uuid, p_path text)
returns void language plpgsql security definer set search_path = public as $$
declare v_jo uuid;
begin
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then
    raise exception 'Invalid proof path.';
  end if;
  select s.job_order_id into v_jo from public.jo_supplements s
    join public.job_orders jo on jo.id = s.job_order_id
    where s.id = p_supp and jo.customer_id = public.current_broker_id() for update;
  if not found then raise exception 'Charge not found.'; end if;
  update public.jo_supplements
    set payment_status = 'submitted', payment_proof_path = p_path,
        payment_submitted_at = now(), payment_note = null
    where id = p_supp;
  insert into public.staff_notifications (required_permission, kind, title, job_order_id)
    values ('review_payments', 'payment', 'Additional-charge payment proof uploaded', v_jo);
end;
$$;
revoke all on function public.submit_supplement_proof(uuid, text) from public, anon;
grant execute on function public.submit_supplement_proof(uuid, text) to authenticated;

-- ---------- cashier reviews a supplement payment (online proof or walk-in) ----------
create or replace function public.review_supplement_payment(p_supp uuid, p_confirm boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_jo uuid;
begin
  if not public.has_permission('review_payments') then
    raise exception 'You don''t have permission to review payments.';
  end if;
  select job_order_id into v_jo from public.jo_supplements where id = p_supp for update;
  if not found then raise exception 'Charge not found.'; end if;
  if not p_confirm and length(coalesce(trim(p_note), '')) = 0 then
    raise exception 'Add a note telling the customer why.' using errcode = 'check_violation';
  end if;
  update public.jo_supplements
    set payment_status = case when p_confirm then 'confirmed' else 'rejected' end,
        payment_confirmed_at = case when p_confirm then now() else null end,
        payment_note = case when p_confirm then null else trim(p_note) end
    where id = p_supp;

  -- Settling the last outstanding charge re-completes the order.
  if p_confirm and public.jo_ready_to_complete(v_jo) then
    update public.job_orders set status = 'completed', completed_at = coalesce(completed_at, now())
      where id = v_jo and status in ('submitted','processing','on_hold');
  end if;

  insert into public.notifications (customer_id, job_order_id, kind, title)
    select customer_id, v_jo,
           case when p_confirm then 'payment_confirmed' else 'payment_rejected' end,
           case when p_confirm then 'Additional-charge payment confirmed'
                else 'Additional-charge payment needs attention — “' || trim(p_note) || '”' end
    from public.job_orders where id = v_jo;
end;
$$;
revoke all on function public.review_supplement_payment(uuid, boolean, text) from public, anon;
grant execute on function public.review_supplement_payment(uuid, boolean, text) to authenticated;

-- ---------- cashier records a walk-in supplement payment ----------
create or replace function public.record_supplement_office_payment(p_supp uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_jo uuid;
begin
  if not public.has_permission('review_payments') then
    raise exception 'You don''t have permission to record payments.';
  end if;
  select job_order_id into v_jo from public.jo_supplements where id = p_supp for update;
  if not found then raise exception 'Charge not found.'; end if;
  update public.jo_supplements
    set payment_status = 'confirmed', payment_confirmed_at = now(), payment_note = null
    where id = p_supp;
  if public.jo_ready_to_complete(v_jo) then
    update public.job_orders set status = 'completed', completed_at = coalesce(completed_at, now())
      where id = v_jo and status in ('submitted','processing','on_hold');
  end if;
  perform public.log_jo_event(v_jo, 'supplement_office_paid', jsonb_build_object('supplement', p_supp));
end;
$$;
revoke all on function public.record_supplement_office_payment(uuid) from public, anon;
grant execute on function public.record_supplement_office_payment(uuid) to authenticated;
