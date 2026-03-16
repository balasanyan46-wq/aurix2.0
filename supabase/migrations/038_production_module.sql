-- ============================================================
-- 038 · Production module (services / orders / execution)
-- ============================================================

-- Helper: admin check through profiles.role
create or replace function public.is_admin_user(uid uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  has_user_id boolean;
  has_id boolean;
  ok boolean := false;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'user_id'
  ) into has_user_id;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'id'
  ) into has_id;

  if has_user_id then
    execute
      'select exists (
         select 1
         from public.profiles p
         where p.user_id = $1 and p.role = ''admin''
       )'
    into ok
    using uid;
  elsif has_id then
    execute
      'select exists (
         select 1
         from public.profiles p
         where p.id = $1 and p.role = ''admin''
       )'
    into ok
    using uid;
  end if;

  return coalesce(ok, false);
end;
$$;

-- Catalog of services
create table if not exists public.service_catalog (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text not null default '',
  category        text not null default 'other'
                  check (category in ('music', 'visual', 'promo', 'other')),
  default_price   numeric null,
  sla_days        int null,
  required_inputs jsonb not null default '{}'::jsonb,
  deliverables    jsonb not null default '{}'::jsonb,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Assignees (internal and external executors)
create table if not exists public.production_assignees (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid unique references auth.users(id) on delete set null,
  full_name      text not null,
  specialization text not null default '',
  contacts       text not null default '',
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Orders grouped by artist and release
create table if not exists public.production_orders (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  release_id uuid null references public.releases(id) on delete set null,
  status     text not null default 'active' check (status in ('active', 'completed', 'canceled')),
  title      text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Order line items (services in process)
create table if not exists public.production_order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references public.production_orders(id) on delete cascade,
  service_id  uuid not null references public.service_catalog(id) on delete restrict,
  status      text not null default 'not_started'
              check (status in ('not_started', 'waiting_artist', 'in_progress', 'review', 'done', 'canceled')),
  assignee_id uuid null references public.production_assignees(id) on delete set null,
  deadline_at timestamptz null,
  brief       jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.production_comments (
  id             uuid primary key default gen_random_uuid(),
  order_item_id  uuid not null references public.production_order_items(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  author_role    text not null check (author_role in ('artist', 'admin', 'assignee')),
  message        text not null,
  created_at     timestamptz not null default now()
);

create table if not exists public.production_files (
  id             uuid primary key default gen_random_uuid(),
  order_item_id  uuid not null references public.production_order_items(id) on delete cascade,
  uploaded_by    uuid not null references auth.users(id) on delete cascade,
  kind           text not null check (kind in ('input', 'output')),
  file_name      text not null,
  mime_type      text not null default '',
  storage_bucket text not null default 'production',
  storage_path   text not null,
  size_bytes     bigint null,
  created_at     timestamptz not null default now()
);

create table if not exists public.production_events (
  id            uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references public.production_order_items(id) on delete cascade,
  event_type    text not null
                check (event_type in ('status_changed', 'assigned', 'file_uploaded', 'deadline_changed', 'comment_added', 'created')),
  payload       jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

create index if not exists idx_service_catalog_active on public.service_catalog(is_active, category);
create index if not exists idx_production_orders_user on public.production_orders(user_id, created_at desc);
create index if not exists idx_production_orders_release on public.production_orders(release_id);
create index if not exists idx_production_items_order on public.production_order_items(order_id, created_at desc);
create index if not exists idx_production_items_status on public.production_order_items(status, deadline_at);
create index if not exists idx_production_items_assignee on public.production_order_items(assignee_id);
create index if not exists idx_production_comments_item on public.production_comments(order_item_id, created_at asc);
create index if not exists idx_production_files_item on public.production_files(order_item_id, created_at desc);
create index if not exists idx_production_events_item on public.production_events(order_item_id, created_at asc);

-- updated_at triggers
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_service_catalog_updated_at on public.service_catalog;
create trigger trg_service_catalog_updated_at
before update on public.service_catalog
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_production_assignees_updated_at on public.production_assignees;
create trigger trg_production_assignees_updated_at
before update on public.production_assignees
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_production_orders_updated_at on public.production_orders;
create trigger trg_production_orders_updated_at
before update on public.production_orders
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_production_items_updated_at on public.production_order_items;
create trigger trg_production_items_updated_at
before update on public.production_order_items
for each row execute procedure public.set_updated_at();

-- RLS enable
alter table public.service_catalog enable row level security;
alter table public.production_assignees enable row level security;
alter table public.production_orders enable row level security;
alter table public.production_order_items enable row level security;
alter table public.production_comments enable row level security;
alter table public.production_files enable row level security;
alter table public.production_events enable row level security;

-- Catalog: everyone authenticated can read, only admin can mutate
drop policy if exists service_catalog_select_auth on public.service_catalog;
create policy service_catalog_select_auth on public.service_catalog
for select using (auth.role() = 'authenticated');

drop policy if exists service_catalog_admin_write on public.service_catalog;
create policy service_catalog_admin_write on public.service_catalog
for all using (public.is_admin_user()) with check (public.is_admin_user());

-- Assignees: readable by authenticated; writable by admin
drop policy if exists production_assignees_select_auth on public.production_assignees;
create policy production_assignees_select_auth on public.production_assignees
for select using (auth.role() = 'authenticated');

drop policy if exists production_assignees_admin_write on public.production_assignees;
create policy production_assignees_admin_write on public.production_assignees
for all using (public.is_admin_user()) with check (public.is_admin_user());

-- Orders
drop policy if exists production_orders_select_own_admin on public.production_orders;
create policy production_orders_select_own_admin on public.production_orders
for select using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists production_orders_insert_own_or_admin on public.production_orders;
create policy production_orders_insert_own_or_admin on public.production_orders
for insert with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists production_orders_update_own_or_admin on public.production_orders;
create policy production_orders_update_own_or_admin on public.production_orders
for update using (user_id = auth.uid() or public.is_admin_user())
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists production_orders_delete_admin on public.production_orders;
create policy production_orders_delete_admin on public.production_orders
for delete using (public.is_admin_user());

-- Helper expression for item access
drop policy if exists production_items_select_scope on public.production_order_items;
create policy production_items_select_scope on public.production_order_items
for select using (
  exists (
    select 1 from public.production_orders o
    where o.id = order_id and (o.user_id = auth.uid() or public.is_admin_user())
  )
  or exists (
    select 1
    from public.production_assignees a
    where a.id = assignee_id and a.user_id = auth.uid()
  )
);

drop policy if exists production_items_insert_scope on public.production_order_items;
create policy production_items_insert_scope on public.production_order_items
for insert with check (
  public.is_admin_user()
  or exists (
    select 1 from public.production_orders o
    where o.id = order_id and o.user_id = auth.uid()
  )
);

drop policy if exists production_items_update_scope on public.production_order_items;
create policy production_items_update_scope on public.production_order_items
for update using (
  public.is_admin_user()
  or exists (
    select 1 from public.production_orders o
    where o.id = order_id and o.user_id = auth.uid()
  )
  or exists (
    select 1 from public.production_assignees a
    where a.id = assignee_id and a.user_id = auth.uid()
  )
)
with check (
  public.is_admin_user()
  or exists (
    select 1 from public.production_orders o
    where o.id = order_id and o.user_id = auth.uid()
  )
  or exists (
    select 1 from public.production_assignees a
    where a.id = assignee_id and a.user_id = auth.uid()
  )
);

drop policy if exists production_items_delete_admin on public.production_order_items;
create policy production_items_delete_admin on public.production_order_items
for delete using (public.is_admin_user());

-- Comments / files / events visibility by item scope
drop policy if exists production_comments_scope on public.production_comments;
create policy production_comments_scope on public.production_comments
for select using (
  exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = order_item_id
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_comments_insert_scope on public.production_comments;
create policy production_comments_insert_scope on public.production_comments
for insert with check (
  author_user_id = auth.uid()
  and exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = order_item_id
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_comments_admin_update_delete on public.production_comments;
create policy production_comments_admin_update_delete on public.production_comments
for all using (public.is_admin_user()) with check (public.is_admin_user());

drop policy if exists production_files_scope on public.production_files;
create policy production_files_scope on public.production_files
for select using (
  exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = order_item_id
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_files_insert_scope on public.production_files;
create policy production_files_insert_scope on public.production_files
for insert with check (
  uploaded_by = auth.uid()
  and exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = order_item_id
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_files_admin_update_delete on public.production_files;
create policy production_files_admin_update_delete on public.production_files
for all using (public.is_admin_user()) with check (public.is_admin_user());

drop policy if exists production_events_scope on public.production_events;
create policy production_events_scope on public.production_events
for select using (
  exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = order_item_id
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_events_insert_scope on public.production_events;
create policy production_events_insert_scope on public.production_events
for insert with check (
  exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = order_item_id
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_events_admin_update_delete on public.production_events;
create policy production_events_admin_update_delete on public.production_events
for all using (public.is_admin_user()) with check (public.is_admin_user());

-- Private storage bucket
insert into storage.buckets (id, name, public)
values ('production', 'production', false)
on conflict (id) do update set public = excluded.public;

-- Storage RLS for production bucket:
-- path: {order_item_id}/input/... or {order_item_id}/output/...
drop policy if exists production_storage_select on storage.objects;
create policy production_storage_select on storage.objects
for select using (
  bucket_id = 'production'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = ((storage.foldername(name))[1])::uuid
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_storage_insert on storage.objects;
create policy production_storage_insert on storage.objects
for insert with check (
  bucket_id = 'production'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = ((storage.foldername(name))[1])::uuid
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_storage_update on storage.objects;
create policy production_storage_update on storage.objects
for update using (
  bucket_id = 'production'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = ((storage.foldername(name))[1])::uuid
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);

drop policy if exists production_storage_delete on storage.objects;
create policy production_storage_delete on storage.objects
for delete using (
  bucket_id = 'production'
  and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.production_order_items i
    join public.production_orders o on o.id = i.order_id
    left join public.production_assignees a on a.id = i.assignee_id
    where i.id = ((storage.foldername(name))[1])::uuid
      and (o.user_id = auth.uid() or public.is_admin_user() or a.user_id = auth.uid())
  )
);
