begin;

create table if not exists public.artist_navigator_materials (
  id text primary key,
  slug text not null unique,
  title text not null,
  subtitle text not null default '',
  excerpt text not null default '',
  body_blocks jsonb not null default '[]'::jsonb,
  category text not null,
  tags text[] not null default '{}',
  platforms text[] not null default '{}',
  stages text[] not null default '{}',
  goals text[] not null default '{}',
  blockers text[] not null default '{}',
  difficulty text not null default 'средний',
  reading_time_minutes int not null default 6,
  format_type text not null default 'guide',
  action_links jsonb not null default '[]'::jsonb,
  source_pack jsonb not null default '[]'::jsonb,
  last_reviewed_at timestamptz null,
  is_featured boolean not null default false,
  is_published boolean not null default true,
  priority_score numeric(6,3) not null default 0.5,
  related_content_ids text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_artist_navigator_materials_updated_at on public.artist_navigator_materials;
create trigger trg_artist_navigator_materials_updated_at
before update on public.artist_navigator_materials
for each row execute procedure public.set_updated_at();

create table if not exists public.artist_navigator_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  onboarding_answers jsonb not null default '{}'::jsonb,
  route_state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_artist_navigator_profiles_updated_at on public.artist_navigator_profiles;
create trigger trg_artist_navigator_profiles_updated_at
before update on public.artist_navigator_profiles
for each row execute procedure public.set_updated_at();

create table if not exists public.artist_navigator_user_materials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  material_id text not null,
  is_saved boolean not null default false,
  is_completed boolean not null default false,
  progress_percent int not null default 0 check (progress_percent between 0 and 100),
  notes text null,
  last_opened_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, material_id)
);

create index if not exists idx_artist_navigator_user_materials_user_saved
  on public.artist_navigator_user_materials(user_id, is_saved);

create index if not exists idx_artist_navigator_user_materials_user_completed
  on public.artist_navigator_user_materials(user_id, is_completed);

drop trigger if exists trg_artist_navigator_user_materials_updated_at on public.artist_navigator_user_materials;
create trigger trg_artist_navigator_user_materials_updated_at
before update on public.artist_navigator_user_materials
for each row execute procedure public.set_updated_at();

alter table public.artist_navigator_materials enable row level security;
alter table public.artist_navigator_profiles enable row level security;
alter table public.artist_navigator_user_materials enable row level security;

drop policy if exists artist_navigator_materials_select_published on public.artist_navigator_materials;
create policy artist_navigator_materials_select_published
on public.artist_navigator_materials
for select
using (is_published = true or public.is_admin_user());

drop policy if exists artist_navigator_materials_admin_manage on public.artist_navigator_materials;
create policy artist_navigator_materials_admin_manage
on public.artist_navigator_materials
for all
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists artist_navigator_profiles_owner_read on public.artist_navigator_profiles;
create policy artist_navigator_profiles_owner_read
on public.artist_navigator_profiles
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists artist_navigator_profiles_owner_insert on public.artist_navigator_profiles;
create policy artist_navigator_profiles_owner_insert
on public.artist_navigator_profiles
for insert
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists artist_navigator_profiles_owner_update on public.artist_navigator_profiles;
create policy artist_navigator_profiles_owner_update
on public.artist_navigator_profiles
for update
using (user_id = auth.uid() or public.is_admin_user())
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists artist_navigator_profiles_admin_manage on public.artist_navigator_profiles;
create policy artist_navigator_profiles_admin_manage
on public.artist_navigator_profiles
for all
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists artist_navigator_user_materials_owner_read on public.artist_navigator_user_materials;
create policy artist_navigator_user_materials_owner_read
on public.artist_navigator_user_materials
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists artist_navigator_user_materials_owner_insert on public.artist_navigator_user_materials;
create policy artist_navigator_user_materials_owner_insert
on public.artist_navigator_user_materials
for insert
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists artist_navigator_user_materials_owner_update on public.artist_navigator_user_materials;
create policy artist_navigator_user_materials_owner_update
on public.artist_navigator_user_materials
for update
using (user_id = auth.uid() or public.is_admin_user())
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists artist_navigator_user_materials_owner_delete on public.artist_navigator_user_materials;
create policy artist_navigator_user_materials_owner_delete
on public.artist_navigator_user_materials
for delete
using (user_id = auth.uid() or public.is_admin_user());

commit;
