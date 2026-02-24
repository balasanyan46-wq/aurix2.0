-- Fix: create support_tickets and support_messages
-- profiles PK in this DB = user_id (not id)

-- support_tickets
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  admin_reply text,
  admin_id uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_support_tickets_user on public.support_tickets(user_id);
create index if not exists idx_support_tickets_status on public.support_tickets(status);

alter table public.support_tickets enable row level security;

drop policy if exists "Users read own tickets" on public.support_tickets;
drop policy if exists "Users create own tickets" on public.support_tickets;
drop policy if exists "Admins update tickets" on public.support_tickets;
drop policy if exists "Users update own tickets" on public.support_tickets;

create policy "Users read own tickets"
  on public.support_tickets for select
  using (
    auth.uid() = user_id
    or exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin')
  );

create policy "Users create own tickets"
  on public.support_tickets for insert
  with check (auth.uid() = user_id);

create policy "Users update own tickets"
  on public.support_tickets for update
  using (
    auth.uid() = user_id
    or exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin')
  );

-- support_messages
create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid references public.support_tickets(id) on delete cascade not null,
  sender_id uuid not null,
  sender_role text not null default 'user' check (sender_role in ('user', 'admin')),
  body text not null,
  created_at timestamptz default now()
);

create index if not exists idx_support_messages_ticket on public.support_messages(ticket_id);
create index if not exists idx_support_messages_created on public.support_messages(ticket_id, created_at);

alter table public.support_messages enable row level security;

drop policy if exists "Users read own ticket messages" on public.support_messages;
drop policy if exists "Users insert own ticket messages" on public.support_messages;

create policy "Users read own ticket messages"
  on public.support_messages for select
  using (
    exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.user_id = auth.uid()
    )
    or exists (
      select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin'
    )
  );

create policy "Users insert own ticket messages"
  on public.support_messages for insert
  with check (
    auth.uid() = sender_id
    and (
      sender_role = 'user' and exists (
        select 1 from public.support_tickets t where t.id = ticket_id and t.user_id = auth.uid()
      )
      or sender_role = 'admin' and exists (
        select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin'
      )
    )
  );
