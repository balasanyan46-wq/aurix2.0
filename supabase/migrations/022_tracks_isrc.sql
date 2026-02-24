-- Добавляем isrc в tracks для matching отчётов
alter table public.tracks add column if not exists isrc text;
create index if not exists idx_tracks_isrc on public.tracks(isrc) where isrc is not null;
