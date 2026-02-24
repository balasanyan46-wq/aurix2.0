-- Migration: release growth plans + budget plans tables for Studio AI tools
-- Run in Supabase SQL Editor

BEGIN;

-- 1) release_growth_plans
create table if not exists public.release_growth_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid not null references public.releases(id) on delete cascade,
  is_demo boolean not null default false,
  input jsonb not null default '{}',
  plan jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, release_id)
);

-- 2) release_budgets
create table if not exists public.release_budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid not null references public.releases(id) on delete cascade,
  is_demo boolean not null default false,
  input jsonb not null default '{}',
  budget jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, release_id)
);

-- updated_at trigger function
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_growth_updated_at on public.release_growth_plans;
create trigger trg_growth_updated_at
before update on public.release_growth_plans
for each row execute function public.set_updated_at();

drop trigger if exists trg_budget_updated_at on public.release_budgets;
create trigger trg_budget_updated_at
before update on public.release_budgets
for each row execute function public.set_updated_at();

-- RLS
alter table public.release_growth_plans enable row level security;
alter table public.release_budgets enable row level security;

-- Growth plan policies
drop policy if exists "growth_select_own" on public.release_growth_plans;
create policy "growth_select_own" on public.release_growth_plans
  for select using (auth.uid() = user_id);

drop policy if exists "growth_insert_own" on public.release_growth_plans;
create policy "growth_insert_own" on public.release_growth_plans
  for insert with check (auth.uid() = user_id);

drop policy if exists "growth_update_own" on public.release_growth_plans;
create policy "growth_update_own" on public.release_growth_plans
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "growth_delete_own" on public.release_growth_plans;
create policy "growth_delete_own" on public.release_growth_plans
  for delete using (auth.uid() = user_id);

-- Budget policies
drop policy if exists "budget_select_own" on public.release_budgets;
create policy "budget_select_own" on public.release_budgets
  for select using (auth.uid() = user_id);

drop policy if exists "budget_insert_own" on public.release_budgets;
create policy "budget_insert_own" on public.release_budgets
  for insert with check (auth.uid() = user_id);

drop policy if exists "budget_update_own" on public.release_budgets;
create policy "budget_update_own" on public.release_budgets
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "budget_delete_own" on public.release_budgets;
create policy "budget_delete_own" on public.release_budgets
  for delete using (auth.uid() = user_id);

-- Admin read access
drop policy if exists "growth_admin_select" on public.release_growth_plans;
create policy "growth_admin_select" on public.release_growth_plans
  for select using (
    exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin')
  );

drop policy if exists "budget_admin_select" on public.release_budgets;
create policy "budget_admin_select" on public.release_budgets
  for select using (
    exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin')
  );

COMMIT;
