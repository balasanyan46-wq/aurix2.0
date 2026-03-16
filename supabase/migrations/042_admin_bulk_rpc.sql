-- ============================================================
-- 042 · Admin bulk RPC and delete-request processor
-- ============================================================

create or replace function public.admin_bulk_update_profiles_status(
  p_user_ids uuid[],
  p_new_status text,
  p_reason text default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
begin
  if not public.is_admin_user() then
    raise exception 'Only admin can bulk update profiles';
  end if;

  if p_user_ids is null or coalesce(array_length(p_user_ids, 1), 0) = 0 then
    return 0;
  end if;

  update public.profiles p
  set account_status = p_new_status,
      updated_at = now()
  where p.user_id = any(p_user_ids);

  get diagnostics v_count = row_count;

  perform public.admin_log_event(
    p_action => 'users_bulk_status_changed',
    p_target_type => 'profiles',
    p_target_id => null,
    p_details => jsonb_build_object(
      'count', v_count,
      'new_status', p_new_status,
      'reason', coalesce(p_reason, '')
    )
  );

  return v_count;
end;
$$;

create or replace function public.admin_bulk_update_releases_status(
  p_release_ids uuid[],
  p_new_status text,
  p_reason text default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
begin
  if not public.is_admin_user() then
    raise exception 'Only admin can bulk update releases';
  end if;

  if p_release_ids is null or coalesce(array_length(p_release_ids, 1), 0) = 0 then
    return 0;
  end if;

  update public.releases r
  set status = p_new_status,
      updated_at = now()
  where r.id = any(p_release_ids);

  get diagnostics v_count = row_count;

  perform public.admin_log_event(
    p_action => 'releases_bulk_status_changed',
    p_target_type => 'releases',
    p_target_id => null,
    p_details => jsonb_build_object(
      'count', v_count,
      'new_status', p_new_status,
      'reason', coalesce(p_reason, '')
    )
  );

  return v_count;
end;
$$;

create or replace function public.admin_process_release_delete_request(
  p_request_id uuid,
  p_decision text,
  p_comment text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mode text := lower(coalesce(p_decision, ''));
  v_updated int := 0;
begin
  if not public.is_admin_user() then
    raise exception 'Only admin can process delete requests';
  end if;

  if v_mode not in ('approve', 'reject') then
    raise exception 'Unsupported decision: %', p_decision;
  end if;

  update public.release_delete_requests
  set status = case when v_mode = 'approve' then 'approved' else 'rejected' end,
      admin_comment = nullif(trim(coalesce(p_comment, '')), ''),
      processed_by = auth.uid(),
      processed_at = now()
  where id = p_request_id
    and status = 'pending';

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    return false;
  end if;

  perform public.admin_log_event(
    p_action => case when v_mode = 'approve'
      then 'release_delete_request_approved'
      else 'release_delete_request_rejected'
    end,
    p_target_type => 'release_delete_request',
    p_target_id => p_request_id,
    p_details => jsonb_build_object('comment', coalesce(p_comment, ''))
  );

  return true;
end;
$$;
