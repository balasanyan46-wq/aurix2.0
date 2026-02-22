-- cover_path в releases (если нет)
alter table public.releases add column if not exists cover_path text;

-- tracks: audio_path, audio_url
alter table public.tracks add column if not exists audio_path text;
alter table public.tracks add column if not exists audio_url text;
-- Заполняем из path/file_url для существующих записей
update public.tracks set audio_path = coalesce(audio_path, path) where path is not null;
update public.tracks set audio_url = coalesce(audio_url, file_url) where file_url is not null;
