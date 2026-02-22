-- Aurix MVP: таблицы, индексы, RLS (без hard delete для профилей/релизов)

-- profiles: личный кабинет навсегда (только account_status, delete запрещён)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  email text not null,
  display_name text,
  artist_name text,
  phone text,
  role text not null default 'artist' check (role in ('artist', 'admin')),
  account_status text not null default 'active' check (account_status in ('active', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_profiles_account_status on public.profiles(account_status);

-- releases
create table if not exists public.releases (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  title text not null,
  release_type text not null check (release_type in ('single', 'ep', 'album')),
  release_date date,
  genre text,
  language text,
  explicit boolean not null default false,
  status text not null default 'draft' check (status in ('draft', 'submitted', 'in_review', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_releases_owner_id on public.releases(owner_id);
create index if not exists idx_releases_status on public.releases(status);

-- files (обложки и треки)
create table if not exists public.files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  release_id uuid references public.releases(id) on delete set null,
  kind text not null check (kind in ('cover', 'track')),
  path text not null,
  mime text,
  size bigint,
  created_at timestamptz not null default now()
);

create index if not exists idx_files_owner_id on public.files(owner_id);
create index if not exists idx_files_release_id on public.files(release_id);

-- admin_notes
create table if not exists public.admin_notes (
  id uuid primary key default gen_random_uuid(),
  release_id uuid not null references public.releases(id) on delete restrict,
  admin_id uuid not null references public.profiles(id) on delete restrict,
  note text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_admin_notes_release_id on public.admin_notes(release_id);

-- updated_at триггер
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger releases_updated_at
  before update on public.releases
  for each row execute function public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;
alter table public.releases enable row level security;
alter table public.files enable row level security;
alter table public.admin_notes enable row level security;

-- profiles: пользователь читает/обновляет только себя; admin читает всех; delete запретить всем
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

-- delete на profiles запрещён: политику на delete не создаём (по умолчанию deny)

-- releases: пользователь видит/создаёт/обновляет только своё; admin — всё; delete запретить
create policy "releases_select" on public.releases
  for select using (
    owner_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

create policy "releases_insert" on public.releases
  for insert with check (owner_id = auth.uid());

create policy "releases_update" on public.releases
  for update using (
    owner_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- files: владелец или admin
create policy "files_select" on public.files
  for select using (
    owner_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

create policy "files_insert" on public.files
  for insert with check (owner_id = auth.uid());

create policy "files_update" on public.files
  for update using (owner_id = auth.uid());

-- admin_notes: автор видит свои, admin всё
create policy "admin_notes_select" on public.admin_notes
  for select using (
    exists (select 1 from public.releases r where r.id = admin_notes.release_id and r.owner_id = auth.uid())
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

create policy "admin_notes_insert" on public.admin_notes
  for insert with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
    and admin_id = auth.uid()
  );

-- Автосоздание профиля при первом входе (через trigger на auth.users или через app upsert)
-- В приложении делаем upsert при входе; здесь можно добавить trigger для insert в profiles из auth.users
-- Для простоты оставляем upsert на стороне приложения.
