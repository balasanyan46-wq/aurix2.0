-- Фикс: добавляет cover_url и cover_path в releases (если их нет)
-- Выполнить в Supabase Dashboard -> SQL Editor

alter table public.releases add column if not exists cover_url text;
alter table public.releases add column if not exists cover_path text;
