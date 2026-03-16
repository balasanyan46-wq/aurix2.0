-- ============================================================
-- 041 · Admin audit log v2
-- ============================================================

alter table public.admin_logs
  add column if not exists actor_role text not null default 'admin',
  add column if not exists correlation_id uuid not null default gen_random_uuid();

create index if not exists idx_admin_logs_target on public.admin_logs(target_type, target_id, created_at desc);
create index if not exists idx_admin_logs_correlation on public.admin_logs(correlation_id);

create or replace function public.admin_log_event(
  p_action text,
  p_target_type text,
  p_target_id uuid default null,
  p_details jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_admin_id uuid := auth.uid();
begin
  if v_admin_id is null or not public.is_admin_user(v_admin_id) then
    raise exception 'Only admin can write admin logs';
  end if;

  insert into public.admin_logs (
    admin_id,
    action,
    target_type,
    target_id,
    details,
    actor_role
  )
  values (
    v_admin_id,
    coalesce(nullif(trim(p_action), ''), 'unknown_action'),
    coalesce(nullif(trim(p_target_type), ''), 'unknown_target'),
    p_target_id,
    coalesce(p_details, '{}'::jsonb),
    'admin'
  )
  returning id into v_id;

  return v_id;
end;
$$;
