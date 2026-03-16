begin;

-- Hotfix: remove recursive sync loop between billing_subscriptions <-> subscriptions.
-- Source of truth is billing_subscriptions; legacy table can be updated one-way only.

drop trigger if exists trg_legacy_subscriptions_sync_billing on public.subscriptions;

create or replace function public.sync_legacy_subscriptions_from_billing()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Guard against nested trigger cascades.
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'subscriptions'
  ) then
    insert into public.subscriptions (user_id, plan, status, billing_period, updated_at)
    values (
      new.user_id,
      public.normalize_plan_slug(new.plan_id),
      case when new.status in ('active', 'trial') then 'active'
           when new.status = 'past_due' then 'past_due'
           when new.status in ('expired', 'canceled') then 'canceled'
           else 'inactive'
      end,
      'monthly',
      now()
    )
    on conflict (user_id) do update
    set
      plan = excluded.plan,
      status = excluded.status,
      updated_at = now();
  end if;
  return new;
end;
$$;

commit;
