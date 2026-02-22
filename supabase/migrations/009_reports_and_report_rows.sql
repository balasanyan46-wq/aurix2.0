-- isrc в tracks для matching отчётов
alter table public.tracks add column if not exists isrc text;
create index if not exists idx_tracks_isrc on public.tracks(isrc) where isrc is not null;

-- reports: импорт квартальных отчётов (Admin only)
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  period_start date not null,
  period_end date not null,
  distributor text not null default 'zvonko',
  file_name text,
  file_url text,
  status text not null default 'uploaded' check (status in ('uploaded', 'parsing', 'ready', 'failed')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_reports_period on public.reports(period_start, period_end);
create index if not exists idx_reports_status on public.reports(status);

alter table public.reports enable row level security;

create policy "reports_select_admin" on public.reports for select using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy "reports_insert_admin" on public.reports for insert with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy "reports_update_admin" on public.reports for update using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- report_rows: нормализованные строки отчёта
create table if not exists public.report_rows (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete cascade,
  report_date date,
  track_title text,
  isrc text,
  platform text,
  country text,
  streams bigint not null default 0,
  revenue decimal(12,4) not null default 0,
  currency text default 'USD',
  track_id uuid references public.tracks(id) on delete set null,
  raw_row_json jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_report_rows_report_id on public.report_rows(report_id);
create index if not exists idx_report_rows_track_id on public.report_rows(track_id);
create index if not exists idx_report_rows_isrc on public.report_rows(isrc) where isrc is not null;

alter table public.report_rows enable row level security;

create policy "report_rows_select_admin" on public.report_rows for select using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy "report_rows_insert_admin" on public.report_rows for insert with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy "report_rows_update_admin" on public.report_rows for update using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
