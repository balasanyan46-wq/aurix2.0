begin;

-- ============================================================
-- AURIX AI Ops Feature Suite (safe additive rollout)
-- ============================================================

-- ------------------------------------------------------------
-- Feature flags
-- ------------------------------------------------------------
create table if not exists public.app_feature_flags (
  key text primary key,
  enabled boolean not null default false,
  rollout text not null default 'off',
  config jsonb not null default '{}'::jsonb,
  updated_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_app_feature_flags_updated_at on public.app_feature_flags;
create trigger trg_app_feature_flags_updated_at
before update on public.app_feature_flags
for each row execute procedure public.set_updated_at();

insert into public.app_feature_flags (key, enabled, rollout, config)
values
  ('release_doctor', false, 'off', '{}'::jsonb),
  ('quality_score', false, 'off', '{}'::jsonb),
  ('promo_autopilot', false, 'off', '{}'::jsonb),
  ('dnk_content_bridge', false, 'off', '{}'::jsonb),
  ('realtime_funnel', false, 'off', '{}'::jsonb),
  ('production_sla_tracker', false, 'off', '{}'::jsonb),
  ('artist_brief', false, 'off', '{}'::jsonb),
  ('weekly_digest', false, 'off', '{}'::jsonb)
on conflict (key) do nothing;

alter table public.app_feature_flags enable row level security;

drop policy if exists app_feature_flags_select_all on public.app_feature_flags;
create policy app_feature_flags_select_all
on public.app_feature_flags
for select
using (true);

drop policy if exists app_feature_flags_admin_manage on public.app_feature_flags;
create policy app_feature_flags_admin_manage
on public.app_feature_flags
for all
using (public.is_admin_user())
with check (public.is_admin_user());

create or replace function public.is_feature_enabled(
  p_key text,
  p_default boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select f.enabled from public.app_feature_flags f where f.key = p_key limit 1),
    p_default
  );
$$;

-- ------------------------------------------------------------
-- Quality score and Release Doctor
-- ------------------------------------------------------------
create table if not exists public.release_quality_scores (
  release_id uuid primary key references public.releases(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  total_score int not null check (total_score between 0 and 100),
  breakdown jsonb not null default '{}'::jsonb,
  status text not null default 'watching' check (status in ('hot', 'accelerating', 'watching', 'quiet')),
  computed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_release_quality_scores_updated_at on public.release_quality_scores;
create trigger trg_release_quality_scores_updated_at
before update on public.release_quality_scores
for each row execute procedure public.set_updated_at();

create table if not exists public.release_doctor_reports (
  id uuid primary key default gen_random_uuid(),
  release_id uuid not null references public.releases(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  quality_score int not null check (quality_score between 0 and 100),
  report jsonb not null default '{}'::jsonb,
  issues_count int not null default 0,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_release_doctor_reports_release_generated
  on public.release_doctor_reports(release_id, generated_at desc);

drop trigger if exists trg_release_doctor_reports_updated_at on public.release_doctor_reports;
create trigger trg_release_doctor_reports_updated_at
before update on public.release_doctor_reports
for each row execute procedure public.set_updated_at();

alter table public.release_quality_scores enable row level security;
alter table public.release_doctor_reports enable row level security;

drop policy if exists release_quality_scores_owner_read on public.release_quality_scores;
create policy release_quality_scores_owner_read
on public.release_quality_scores
for select
using (owner_id = auth.uid() or public.is_admin_user());

drop policy if exists release_quality_scores_admin_manage on public.release_quality_scores;
create policy release_quality_scores_admin_manage
on public.release_quality_scores
for all
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists release_doctor_reports_owner_read on public.release_doctor_reports;
create policy release_doctor_reports_owner_read
on public.release_doctor_reports
for select
using (owner_id = auth.uid() or public.is_admin_user());

drop policy if exists release_doctor_reports_owner_insert on public.release_doctor_reports;
create policy release_doctor_reports_owner_insert
on public.release_doctor_reports
for insert
with check (owner_id = auth.uid() or public.is_admin_user());

drop policy if exists release_doctor_reports_admin_manage on public.release_doctor_reports;
create policy release_doctor_reports_admin_manage
on public.release_doctor_reports
for all
using (public.is_admin_user())
with check (public.is_admin_user());

-- ------------------------------------------------------------
-- Promo Autopilot
-- ------------------------------------------------------------
create table if not exists public.promo_autopilot_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid null references public.releases(id) on delete set null,
  source text not null default 'promo' check (source in ('promo', 'manual', 'admin')),
  status text not null default 'draft' check (status in ('draft', 'active', 'completed', 'failed', 'canceled')),
  plan jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_promo_autopilot_runs_user_started
  on public.promo_autopilot_runs(user_id, started_at desc);

drop trigger if exists trg_promo_autopilot_runs_updated_at on public.promo_autopilot_runs;
create trigger trg_promo_autopilot_runs_updated_at
before update on public.promo_autopilot_runs
for each row execute procedure public.set_updated_at();

create table if not exists public.promo_autopilot_steps (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.promo_autopilot_runs(id) on delete cascade,
  day_no int not null check (day_no between 1 and 60),
  title text not null,
  action_type text not null default 'content',
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'done', 'skipped')),
  due_at timestamptz null,
  done_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (run_id, day_no, title)
);

drop trigger if exists trg_promo_autopilot_steps_updated_at on public.promo_autopilot_steps;
create trigger trg_promo_autopilot_steps_updated_at
before update on public.promo_autopilot_steps
for each row execute procedure public.set_updated_at();

alter table public.promo_autopilot_runs enable row level security;
alter table public.promo_autopilot_steps enable row level security;

drop policy if exists promo_autopilot_runs_owner_read on public.promo_autopilot_runs;
create policy promo_autopilot_runs_owner_read
on public.promo_autopilot_runs
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists promo_autopilot_runs_owner_write on public.promo_autopilot_runs;
create policy promo_autopilot_runs_owner_write
on public.promo_autopilot_runs
for insert
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists promo_autopilot_runs_admin_manage on public.promo_autopilot_runs;
create policy promo_autopilot_runs_admin_manage
on public.promo_autopilot_runs
for all
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists promo_autopilot_steps_owner_read on public.promo_autopilot_steps;
create policy promo_autopilot_steps_owner_read
on public.promo_autopilot_steps
for select
using (
  exists (
    select 1
    from public.promo_autopilot_runs r
    where r.id = run_id
      and (r.user_id = auth.uid() or public.is_admin_user())
  )
);

drop policy if exists promo_autopilot_steps_owner_write on public.promo_autopilot_steps;
create policy promo_autopilot_steps_owner_write
on public.promo_autopilot_steps
for insert
with check (
  exists (
    select 1
    from public.promo_autopilot_runs r
    where r.id = run_id
      and (r.user_id = auth.uid() or public.is_admin_user())
  )
);

drop policy if exists promo_autopilot_steps_owner_update on public.promo_autopilot_steps;
create policy promo_autopilot_steps_owner_update
on public.promo_autopilot_steps
for update
using (
  exists (
    select 1
    from public.promo_autopilot_runs r
    where r.id = run_id
      and (r.user_id = auth.uid() or public.is_admin_user())
  )
)
with check (
  exists (
    select 1
    from public.promo_autopilot_runs r
    where r.id = run_id
      and (r.user_id = auth.uid() or public.is_admin_user())
  )
);

drop policy if exists promo_autopilot_steps_admin_manage on public.promo_autopilot_steps;
create policy promo_autopilot_steps_admin_manage
on public.promo_autopilot_steps
for all
using (public.is_admin_user())
with check (public.is_admin_user());

-- ------------------------------------------------------------
-- Artist brief
-- ------------------------------------------------------------
create table if not exists public.artist_briefs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid null references public.releases(id) on delete set null,
  title text not null default 'Artist Brief',
  payload jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_artist_briefs_user_generated
  on public.artist_briefs(user_id, generated_at desc);

drop trigger if exists trg_artist_briefs_updated_at on public.artist_briefs;
create trigger trg_artist_briefs_updated_at
before update on public.artist_briefs
for each row execute procedure public.set_updated_at();

alter table public.artist_briefs enable row level security;

drop policy if exists artist_briefs_owner_read on public.artist_briefs;
create policy artist_briefs_owner_read
on public.artist_briefs
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists artist_briefs_owner_write on public.artist_briefs;
create policy artist_briefs_owner_write
on public.artist_briefs
for insert
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists artist_briefs_admin_manage on public.artist_briefs;
create policy artist_briefs_admin_manage
on public.artist_briefs
for all
using (public.is_admin_user())
with check (public.is_admin_user());

-- ------------------------------------------------------------
-- Weekly digest
-- ------------------------------------------------------------
create table if not exists public.weekly_digests (
  id uuid primary key default gen_random_uuid(),
  scope text not null check (scope in ('artist', 'admin')),
  user_id uuid null references auth.users(id) on delete cascade,
  week_start date not null,
  week_end date not null,
  title text not null,
  summary text not null,
  metrics jsonb not null default '{}'::jsonb,
  priorities jsonb not null default '[]'::jsonb,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (scope, user_id, week_start)
);

drop trigger if exists trg_weekly_digests_updated_at on public.weekly_digests;
create trigger trg_weekly_digests_updated_at
before update on public.weekly_digests
for each row execute procedure public.set_updated_at();

alter table public.weekly_digests enable row level security;

drop policy if exists weekly_digests_artist_read on public.weekly_digests;
create policy weekly_digests_artist_read
on public.weekly_digests
for select
using (
  (scope = 'artist' and user_id = auth.uid())
  or public.is_admin_user()
);

drop policy if exists weekly_digests_artist_write on public.weekly_digests;
create policy weekly_digests_artist_write
on public.weekly_digests
for insert
with check (
  (scope = 'artist' and user_id = auth.uid())
  or public.is_admin_user()
);

drop policy if exists weekly_digests_admin_manage on public.weekly_digests;
create policy weekly_digests_admin_manage
on public.weekly_digests
for all
using (public.is_admin_user())
with check (public.is_admin_user());

-- ------------------------------------------------------------
-- Production SLA events
-- ------------------------------------------------------------
create table if not exists public.production_sla_events (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references public.production_order_items(id) on delete cascade,
  order_id uuid not null references public.production_orders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in ('sla_ok', 'sla_risk', 'sla_overdue', 'sla_escalated', 'sla_resolved')),
  severity text not null default 'info' check (severity in ('info', 'warning', 'critical')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_production_sla_events_item_created
  on public.production_sla_events(order_item_id, created_at desc);

create index if not exists idx_production_sla_events_user_created
  on public.production_sla_events(user_id, created_at desc);

alter table public.production_sla_events enable row level security;

drop policy if exists production_sla_events_artist_read on public.production_sla_events;
create policy production_sla_events_artist_read
on public.production_sla_events
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists production_sla_events_admin_manage on public.production_sla_events;
create policy production_sla_events_admin_manage
on public.production_sla_events
for all
using (public.is_admin_user())
with check (public.is_admin_user());

commit;
