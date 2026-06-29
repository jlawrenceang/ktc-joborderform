-- ============================================================
-- 0200 — staff_notification_reads: evicted/dead JWT loses access (audit #7)
--
-- The three staff_notification_reads policies (0085) gated on raw auth.uid(), so
-- an evicted / auto-suspended staff session could keep reading + writing its
-- read-markers until the access token expired (~1h). Mirrors the 0118 fix:
-- current_uid_alive() returns NULL once the session row is gone, so the policy
-- fails instantly for a dead/evicted JWT. (The notifications themselves, line 44,
-- gate on has_permission(), which already weaves session_alive().)
-- ============================================================

drop policy if exists "read own staff notif reads" on public.staff_notification_reads;
create policy "read own staff notif reads" on public.staff_notification_reads
  for select to authenticated using (staff_uid = public.current_uid_alive());

drop policy if exists "insert own staff notif reads" on public.staff_notification_reads;
create policy "insert own staff notif reads" on public.staff_notification_reads
  for insert to authenticated with check (staff_uid = public.current_uid_alive());

drop policy if exists "delete own staff notif reads" on public.staff_notification_reads;
create policy "delete own staff notif reads" on public.staff_notification_reads
  for delete to authenticated using (staff_uid = public.current_uid_alive());
