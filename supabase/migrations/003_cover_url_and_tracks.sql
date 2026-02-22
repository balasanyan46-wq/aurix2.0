-- cover_url в releases
alter table public.releases add column if not exists cover_url text;

-- tracks: треки релиза (path в storage, file_url публичный)
create table if not exists public.tracks (
  id uuid primary key default gen_random_uuid(),
  release_id uuid not null references public.releases(id) on delete cascade,
  path text not null,
  file_url text not null,
  title text,
  track_number int not null default 0,
  version text default 'original' check (version in ('original', 'remix', 'instrumental')),
  explicit boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_tracks_release_id on public.tracks(release_id);

alter table public.tracks enable row level security;

create policy "tracks_select" on public.tracks for select using (
  exists (select 1 from public.releases r where r.id = tracks.release_id and (r.owner_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')))
);

create policy "tracks_insert" on public.tracks for insert with check (
  exists (select 1 from public.releases r where r.id = release_id and r.owner_id = auth.uid())
);

create policy "tracks_update" on public.tracks for update using (
  exists (select 1 from public.releases r where r.id = tracks.release_id and (r.owner_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')))
);

create policy "tracks_delete" on public.tracks for delete using (
  exists (select 1 from public.releases r where r.id = tracks.release_id and r.owner_id = auth.uid())
);
