begin;

alter table if exists public.artist_navigator_materials
  add column if not exists related_tools text[] not null default '{}';

update public.artist_navigator_materials
set related_tools = '{}'
where related_tools is null;

commit;
