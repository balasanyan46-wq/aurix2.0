-- Добавляем недостающие колонки в profiles
alter table public.profiles add column if not exists artist_name text;
alter table public.profiles add column if not exists name text;
alter table public.profiles add column if not exists city text;
alter table public.profiles add column if not exists gender text;
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists plan text not null default 'start';
alter table public.profiles add column if not exists display_name text;
