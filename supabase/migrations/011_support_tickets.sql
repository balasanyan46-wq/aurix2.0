-- Support tickets
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  admin_reply text,
  admin_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_support_tickets_user on public.support_tickets(user_id);
create index if not exists idx_support_tickets_status on public.support_tickets(status);

alter table public.support_tickets enable row level security;

-- Users can read their own tickets
create policy "Users read own tickets"
  on public.support_tickets for select
  using (auth.uid() = user_id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- Users can create their own tickets
create policy "Users create own tickets"
  on public.support_tickets for insert
  with check (auth.uid() = user_id);

-- Users can update their own tickets (reopen etc.)
create policy "Users update own tickets"
  on public.support_tickets for update
  using (auth.uid() = user_id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
