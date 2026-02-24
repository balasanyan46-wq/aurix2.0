-- Дополнительные поля для полной дистрибуции
alter table public.releases add column if not exists upc text;
alter table public.releases add column if not exists label text;
alter table public.releases add column if not exists copyright_year int;

create index if not exists idx_releases_upc on public.releases(upc) where upc is not null;
