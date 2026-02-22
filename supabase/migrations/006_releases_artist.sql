-- artist в releases (если нет)
alter table public.releases add column if not exists artist text;
