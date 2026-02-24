-- Chat messages for support tickets
create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid references public.support_tickets(id) on delete cascade not null,
  sender_id uuid references public.profiles(user_id) on delete cascade not null,
  sender_role text not null default 'user' check (sender_role in ('user', 'admin')),
  body text not null,
  created_at timestamptz default now()
);

create index if not exists idx_support_messages_ticket on public.support_messages(ticket_id);
create index if not exists idx_support_messages_created on public.support_messages(ticket_id, created_at);

alter table public.support_messages enable row level security;

-- Users can read messages on their own tickets
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

-- Users can insert messages on their own tickets
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
