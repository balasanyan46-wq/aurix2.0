-- ============================================================
-- 045 · RLS hardening for admin critical paths
-- ============================================================

-- admin_logs: prevent spoofed admin_id and enforce admin role.
drop policy if exists "Admins can insert logs" on public.admin_logs;
create policy "Admins can insert logs"
  on public.admin_logs
  for insert
  with check (
    public.is_admin_user()
    and admin_id = auth.uid()
  );

drop policy if exists "Admins can read all logs" on public.admin_logs;
create policy "Admins can read all logs"
  on public.admin_logs
  for select
  using (public.is_admin_user());

-- reports: explicit admin delete/update protection.
drop policy if exists reports_admin_manage on public.reports;
create policy reports_admin_manage
  on public.reports
  for all
  using (public.is_admin_user())
  with check (public.is_admin_user());

drop policy if exists report_rows_admin_manage on public.report_rows;
create policy report_rows_admin_manage
  on public.report_rows
  for all
  using (public.is_admin_user())
  with check (public.is_admin_user());

-- releases: explicit admin delete guard.
drop policy if exists admin_delete_all_releases on public.releases;
create policy admin_delete_all_releases
  on public.releases
  for delete
  using (public.is_admin_user());

-- support_tickets: explicit admin management policy for all operations.
drop policy if exists support_tickets_admin_manage on public.support_tickets;
create policy support_tickets_admin_manage
  on public.support_tickets
  for all
  using (public.is_admin_user())
  with check (public.is_admin_user());

-- reports dedup safety for repeated CSV imports
alter table public.reports
  add column if not exists import_hash text;

create unique index if not exists uniq_reports_import_hash
  on public.reports(import_hash)
  where import_hash is not null;
