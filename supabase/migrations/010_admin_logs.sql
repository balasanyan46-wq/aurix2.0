-- Admin audit log
create table if not exists public.admin_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles(user_id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  details jsonb default '{}',
  created_at timestamptz default now()
);

create index if not exists idx_admin_logs_created on public.admin_logs(created_at desc);
create index if not exists idx_admin_logs_action on public.admin_logs(action);

alter table public.admin_logs enable row level security;

create policy "Admins can read all logs"
  on public.admin_logs for select
  using (exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin'));

create policy "Admins can insert logs"
  on public.admin_logs for insert
  with check (exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin'));
