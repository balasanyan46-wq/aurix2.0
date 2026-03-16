-- ============================================================
-- 047 · Promo requests module
-- ============================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'promo_request_type') then
    create type public.promo_request_type as enum (
      'dsp_pitch',
      'aurix_pitch',
      'influencer',
      'ads'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'promo_request_status') then
    create type public.promo_request_status as enum (
      'submitted',
      'under_review',
      'approved',
      'rejected',
      'in_progress',
      'completed'
    );
  end if;
end $$;

create table if not exists public.promo_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid not null references public.releases(id) on delete cascade,
  type public.promo_request_type not null,
  status public.promo_request_status not null default 'submitted',
  form_data jsonb not null default '{}'::jsonb,
  admin_notes text,
  assigned_manager uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.promo_events (
  id uuid primary key default gen_random_uuid(),
  promo_request_id uuid not null references public.promo_requests(id) on delete cascade,
  event_type text not null check (event_type in ('status_changed', 'comment_added', 'assigned')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_promo_requests_user_created
  on public.promo_requests(user_id, created_at desc);

create index if not exists idx_promo_requests_release_created
  on public.promo_requests(release_id, created_at desc);

create index if not exists idx_promo_requests_status_type
  on public.promo_requests(status, type, created_at desc);

create index if not exists idx_promo_events_request_created
  on public.promo_events(promo_request_id, created_at desc);

create unique index if not exists uniq_promo_request_single_active_type
  on public.promo_requests(user_id, release_id, type)
  where status in ('submitted', 'under_review', 'approved', 'in_progress');

create or replace function public.set_promo_requests_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_promo_requests_updated_at on public.promo_requests;
create trigger trg_promo_requests_updated_at
before update on public.promo_requests
for each row execute procedure public.set_promo_requests_updated_at();

alter table public.promo_requests enable row level security;
alter table public.promo_events enable row level security;

drop policy if exists promo_requests_owner_select on public.promo_requests;
create policy promo_requests_owner_select
  on public.promo_requests
  for select
  using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists promo_requests_owner_insert on public.promo_requests;
create policy promo_requests_owner_insert
  on public.promo_requests
  for insert
  with check (
    (user_id = auth.uid() and exists (
      select 1
      from public.releases r
      where r.id = promo_requests.release_id
        and r.owner_id = auth.uid()
    ))
    or public.is_admin_user()
  );

drop policy if exists promo_requests_owner_update on public.promo_requests;
create policy promo_requests_owner_update
  on public.promo_requests
  for update
  using (user_id = auth.uid() or public.is_admin_user())
  with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists promo_requests_admin_delete on public.promo_requests;
create policy promo_requests_admin_delete
  on public.promo_requests
  for delete
  using (public.is_admin_user());

drop policy if exists promo_events_select on public.promo_events;
create policy promo_events_select
  on public.promo_events
  for select
  using (
    public.is_admin_user()
    or exists (
      select 1
      from public.promo_requests pr
      where pr.id = promo_events.promo_request_id
        and pr.user_id = auth.uid()
    )
  );

drop policy if exists promo_events_insert on public.promo_events;
create policy promo_events_insert
  on public.promo_events
  for insert
  with check (
    public.is_admin_user()
    or exists (
      select 1
      from public.promo_requests pr
      where pr.id = promo_events.promo_request_id
        and pr.user_id = auth.uid()
    )
  );

drop policy if exists promo_events_admin_manage on public.promo_events;
create policy promo_events_admin_manage
  on public.promo_events
  for update
  using (public.is_admin_user())
  with check (public.is_admin_user());
