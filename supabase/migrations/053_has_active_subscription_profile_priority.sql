begin;

-- Make access checks react immediately to admin tariff changes.
-- We prioritize profiles fields as current source of truth for gating,
-- and fall back to billing_subscriptions when profile fields are missing.
create or replace function public.has_active_subscription(p_user uuid, p_required_plan text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_required int := public.billing_plan_rank(p_required_plan);
  v_plan text;
begin
  if p_user is null then
    return false;
  end if;

  -- Priority 1: profiles shadow fields (updated immediately by admin actions).
  select coalesce(nullif(p.plan_id, ''), p.plan, 'start')
    into v_plan
  from public.profiles p
  where p.user_id = p_user
    and coalesce(p.subscription_status, 'trial') in ('active', 'trial')
    and coalesce(p.subscription_end, now() + interval '1 day') > now()
  limit 1;

  -- Priority 2: billing table fallback.
  if v_plan is null then
    select bs.plan_id
      into v_plan
    from public.billing_subscriptions bs
    where bs.user_id = p_user
      and bs.status in ('active', 'trial')
      and bs.current_period_end > now()
    order by bs.updated_at desc nulls last, bs.created_at desc
    limit 1;
  end if;

  if v_plan is null then
    return false;
  end if;

  return public.billing_plan_rank(v_plan) >= v_required;
end;
$$;

commit;
