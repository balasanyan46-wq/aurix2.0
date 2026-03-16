-- ============================================================
-- 061 · Legal/Compliance core tables
-- - account_deletion_requests
-- - legal_acceptances
-- - cookie_consents
-- ============================================================

begin;

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email_snapshot text,
  reason text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'completed')),
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists idx_account_deletion_requests_user_created
  on public.account_deletion_requests(user_id, created_at desc);
create index if not exists idx_account_deletion_requests_status_created
  on public.account_deletion_requests(status, created_at desc);

create table if not exists public.legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  doc_slug text not null check (doc_slug in ('privacy', 'terms', 'offer', 'cookies', 'refunds')),
  version text not null,
  accepted_at timestamptz not null default now(),
  acceptance_source text not null default 'app'
);

create index if not exists idx_legal_acceptances_user_doc
  on public.legal_acceptances(user_id, doc_slug, accepted_at desc);

create table if not exists public.cookie_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  analytics_allowed boolean not null default true,
  marketing_allowed boolean not null default false,
  source text not null default 'settings',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_cookie_consents_updated_at
  on public.cookie_consents(updated_at desc);

create or replace function public.set_updated_at_account_deletion_requests()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.set_updated_at_cookie_consents()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_account_deletion_requests_updated_at on public.account_deletion_requests;
create trigger trg_account_deletion_requests_updated_at
before update on public.account_deletion_requests
for each row execute procedure public.set_updated_at_account_deletion_requests();

drop trigger if exists trg_cookie_consents_updated_at on public.cookie_consents;
create trigger trg_cookie_consents_updated_at
before update on public.cookie_consents
for each row execute procedure public.set_updated_at_cookie_consents();

alter table public.account_deletion_requests enable row level security;
alter table public.legal_acceptances enable row level security;
alter table public.cookie_consents enable row level security;

drop policy if exists account_deletion_requests_select_own_or_admin on public.account_deletion_requests;
drop policy if exists account_deletion_requests_insert_own on public.account_deletion_requests;
drop policy if exists account_deletion_requests_update_admin on public.account_deletion_requests;

create policy account_deletion_requests_select_own_or_admin
  on public.account_deletion_requests
  for select
  using (
    user_id = auth.uid()
    or public.is_admin()
  );

create policy account_deletion_requests_insert_own
  on public.account_deletion_requests
  for insert
  with check (
    user_id = auth.uid()
  );

create policy account_deletion_requests_update_admin
  on public.account_deletion_requests
  for update
  using (
    public.is_admin()
  )
  with check (
    public.is_admin()
  );

drop policy if exists legal_acceptances_select_own_or_admin on public.legal_acceptances;
drop policy if exists legal_acceptances_insert_own on public.legal_acceptances;

create policy legal_acceptances_select_own_or_admin
  on public.legal_acceptances
  for select
  using (
    user_id = auth.uid()
    or public.is_admin()
  );

create policy legal_acceptances_insert_own
  on public.legal_acceptances
  for insert
  with check (
    user_id = auth.uid()
  );

drop policy if exists cookie_consents_select_own_or_admin on public.cookie_consents;
drop policy if exists cookie_consents_insert_own on public.cookie_consents;
drop policy if exists cookie_consents_update_own_or_admin on public.cookie_consents;

create policy cookie_consents_select_own_or_admin
  on public.cookie_consents
  for select
  using (
    user_id = auth.uid()
    or public.is_admin()
  );

create policy cookie_consents_insert_own
  on public.cookie_consents
  for insert
  with check (
    user_id = auth.uid()
  );

create policy cookie_consents_update_own_or_admin
  on public.cookie_consents
  for update
  using (
    user_id = auth.uid()
    or public.is_admin()
  )
  with check (
    user_id = auth.uid()
    or public.is_admin()
  );

commit;
