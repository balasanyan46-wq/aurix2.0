-- ============================================================
-- 046 · Reports scope by user/release
-- ============================================================
-- Goal:
-- 1) Explicitly bind each report and report row to an artist and release.
-- 2) Guarantee that artists only see their own reports/rows.
-- 3) Keep admin full access through existing is_admin_user() policies.

alter table public.reports
  add column if not exists user_id uuid,
  add column if not exists release_id uuid references public.releases(id) on delete set null;

alter table public.report_rows
  add column if not exists user_id uuid,
  add column if not exists release_id uuid references public.releases(id) on delete set null;

create index if not exists idx_reports_user_id on public.reports(user_id, created_at desc);
create index if not exists idx_reports_release_id on public.reports(release_id, created_at desc);
create index if not exists idx_report_rows_user_release on public.report_rows(user_id, release_id, created_at desc);

-- Backfill reports scope from already matched rows (track_id -> release -> owner).
update public.reports r
set
  release_id = coalesce(r.release_id, src.release_id),
  user_id = coalesce(r.user_id, src.owner_id)
from (
  select
    rr.report_id,
    min(t.release_id::text)::uuid as release_id,
    min(rel.owner_id::text)::uuid as owner_id
  from public.report_rows rr
  join public.tracks t on t.id = rr.track_id
  join public.releases rel on rel.id = t.release_id
  group by rr.report_id
) src
where r.id = src.report_id
  and (r.release_id is null or r.user_id is null);

-- Backfill report_rows from parent report first.
update public.report_rows rr
set
  user_id = coalesce(rr.user_id, r.user_id),
  release_id = coalesce(rr.release_id, r.release_id)
from public.reports r
where rr.report_id = r.id
  and (rr.user_id is null or rr.release_id is null);

-- Backfill remaining rows from track ownership.
update public.report_rows rr
set
  release_id = t.release_id,
  user_id = rel.owner_id
from public.tracks t
join public.releases rel on rel.id = t.release_id
where rr.track_id = t.id
  and (rr.user_id is null or rr.release_id is null);

-- Auto-fill row scope from parent report on insert/update.
create or replace function public.report_rows_fill_scope()
returns trigger
language plpgsql
as $$
declare
  v_user_id uuid;
  v_release_id uuid;
begin
  if new.report_id is not null and (new.user_id is null or new.release_id is null) then
    select r.user_id, r.release_id
      into v_user_id, v_release_id
    from public.reports r
    where r.id = new.report_id;

    if new.user_id is null then
      new.user_id = v_user_id;
    end if;
    if new.release_id is null then
      new.release_id = v_release_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_report_rows_fill_scope on public.report_rows;
create trigger trg_report_rows_fill_scope
before insert or update on public.report_rows
for each row execute procedure public.report_rows_fill_scope();

-- Replace user-facing read policies with explicit scoped access.
drop policy if exists "Users read own report rows" on public.report_rows;
create policy "Users read own report rows"
  on public.report_rows
  for select
  using (
    user_id = auth.uid()
    or (
      release_id is not null
      and exists (
        select 1 from public.releases rel
        where rel.id = report_rows.release_id
          and rel.owner_id = auth.uid()
      )
    )
    or public.is_admin_user()
  );

drop policy if exists "Users read related reports" on public.reports;
create policy "Users read related reports"
  on public.reports
  for select
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.report_rows rr
      where rr.report_id = reports.id
        and rr.user_id = auth.uid()
    )
    or public.is_admin_user()
  );
