create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(user_id) on delete cascade not null,
  member_name text not null,
  member_email text,
  role text not null default 'producer' check (role in ('producer', 'manager', 'engineer', 'songwriter', 'designer', 'other')),
  split_percent numeric(5,2) not null default 0 check (split_percent >= 0 and split_percent <= 100),
  status text not null default 'active' check (status in ('invited', 'active', 'removed')),
  created_at timestamptz default now()
);

alter table public.team_members enable row level security;

create policy "Users read own team" on public.team_members
  for select using (auth.uid() = owner_id);

create policy "Users manage own team" on public.team_members
  for insert with check (auth.uid() = owner_id);

create policy "Users update own team" on public.team_members
  for update using (auth.uid() = owner_id);

create policy "Users delete own team" on public.team_members
  for delete using (auth.uid() = owner_id);

create policy "Admins read all team" on public.team_members
  for select using (public.is_admin());
