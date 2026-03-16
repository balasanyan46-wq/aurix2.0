-- ============================================================
-- 040 · Profiles identity unification and admin helper
-- ============================================================

do $$
declare
  has_id boolean;
  has_user_id boolean;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'id'
  ) into has_id;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'user_id'
  ) into has_user_id;

  if has_id and not has_user_id then
    execute 'alter table public.profiles add column user_id uuid';
    execute 'update public.profiles set user_id = id where user_id is null';
    execute 'create unique index if not exists idx_profiles_user_id_unique on public.profiles(user_id)';
  end if;
end $$;

create unique index if not exists idx_profiles_user_id_unique on public.profiles(user_id);

create or replace function public.is_admin_user(uid uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  ok boolean := false;
begin
  -- Primary path for this project: profiles.user_id
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'user_id'
  ) then
    execute
      'select exists (
         select 1
         from public.profiles p
         where p.user_id = $1 and p.role = ''admin''
       )'
    into ok
    using uid;
    return coalesce(ok, false);
  end if;

  -- Compatibility path: profiles.id
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'id'
  ) then
    execute
      'select exists (
         select 1
         from public.profiles p
         where p.id = $1 and p.role = ''admin''
       )'
    into ok
    using uid;
    return coalesce(ok, false);
  end if;

  return false;
end;
$$;
