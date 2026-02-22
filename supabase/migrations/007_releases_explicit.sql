-- Добавить explicit в releases (если нет)
alter table public.releases add column if not exists explicit boolean not null default false;
