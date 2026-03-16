-- ============================================================
-- 059 · Security Advisor fixes
-- - Remove SECURITY DEFINER-like behavior from public views
-- - Enforce RLS on public.progress_habits
-- ============================================================

begin;

-- ------------------------------------------------------------------
-- A) Admin helper: normalized admin check for policies
-- ------------------------------------------------------------------
create or replace function public.is_admin(uid uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  has_user_id boolean;
  has_id boolean;
  ok boolean := false;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'user_id'
  ) into has_user_id;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'id'
  ) into has_id;

  if has_user_id then
    execute
      'select exists (
         select 1
         from public.profiles p
         where p.user_id = $1 and p.role = ''admin''
       )'
    into ok
    using uid;
    return coalesce(ok, false);
  elsif has_id then
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

revoke all on function public.is_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to authenticated;

-- ------------------------------------------------------------------
-- B) Views: make them SECURITY INVOKER (safe for public schema)
-- ------------------------------------------------------------------
create or replace view public.admin_ops_delete_requests_queue
with (security_invoker = true) as
select
  status,
  count(*)::int as total,
  min(created_at) as oldest_created_at,
  max(created_at) as newest_created_at
from public.release_delete_requests
group by status;

create or replace view public.admin_ops_production_overdue
with (security_invoker = true) as
select
  i.id as item_id,
  i.order_id,
  i.status,
  i.deadline_at,
  o.user_id,
  s.title as service_title,
  (now() - i.deadline_at) as overdue_by
from public.production_order_items i
join public.production_orders o on o.id = i.order_id
left join public.service_catalog s on s.id = i.service_id
where i.deadline_at is not null
  and i.status not in ('done', 'canceled')
  and i.deadline_at < now();

create or replace view public.admin_ops_support_overdue
with (security_invoker = true) as
select
  id as ticket_id,
  user_id,
  status,
  priority,
  due_at,
  escalation_level,
  (now() - due_at) as overdue_by
from public.support_tickets
where status in ('open', 'in_progress')
  and due_at is not null
  and due_at < now();

create or replace view public.support_sla_view
with (security_invoker = true) as
select
  t.id,
  t.user_id,
  t.status,
  t.priority,
  t.created_at,
  t.updated_at,
  t.first_response_at,
  t.resolved_at,
  t.due_at,
  t.escalation_level,
  case
    when t.status in ('resolved', 'closed') then false
    when t.due_at is null then false
    when now() > t.due_at then true
    else false
  end as is_overdue
from public.support_tickets t;

create or replace view public.admin_ops_reports_health
with (security_invoker = true) as
select
  r.id as report_id,
  r.status,
  r.created_at,
  coalesce(rows_cnt.cnt, 0)::int as rows_count,
  coalesce(matched_cnt.cnt, 0)::int as matched_rows_count
from public.reports r
left join (
  select report_id, count(*) as cnt
  from public.report_rows
  group by report_id
) rows_cnt on rows_cnt.report_id = r.id
left join (
  select report_id, count(*) as cnt
  from public.report_rows
  where track_id is not null
  group by report_id
) matched_cnt on matched_cnt.report_id = r.id;

-- ------------------------------------------------------------------
-- C) progress_habits: enforce RLS + strict policies
-- ------------------------------------------------------------------
-- Safety for drifted environments: ensure user_id exists.
do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'progress_habits'
      and column_name = 'user_id'
  ) then
    alter table public.progress_habits add column user_id uuid;
    alter table public.progress_habits
      add constraint progress_habits_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
    create index if not exists idx_progress_habits_user_id
      on public.progress_habits(user_id);
  end if;
end $$;

alter table public.progress_habits enable row level security;

drop policy if exists progress_habits_select_own on public.progress_habits;
drop policy if exists progress_habits_insert_own on public.progress_habits;
drop policy if exists progress_habits_update_own on public.progress_habits;
drop policy if exists progress_habits_delete_own on public.progress_habits;

create policy progress_habits_select_own on public.progress_habits
  for select
  using (
    user_id = auth.uid()
    or public.is_admin(auth.uid())
  );

create policy progress_habits_insert_own on public.progress_habits
  for insert
  with check (
    user_id = auth.uid()
    or public.is_admin(auth.uid())
  );

create policy progress_habits_update_own on public.progress_habits
  for update
  using (
    user_id = auth.uid()
    or public.is_admin(auth.uid())
  )
  with check (
    user_id = auth.uid()
    or public.is_admin(auth.uid())
  );

create policy progress_habits_delete_own on public.progress_habits
  for delete
  using (
    user_id = auth.uid()
    or public.is_admin(auth.uid())
  );

commit;
