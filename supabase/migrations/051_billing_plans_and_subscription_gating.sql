begin;

-- ------------------------------------------------------------
-- Plans catalog
-- ------------------------------------------------------------
create table if not exists public.billing_plans (
  id text primary key,
  title text not null,
  price_monthly int not null check (price_monthly >= 0),
  ai_limit int not null check (ai_limit >= 0),
  features jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

insert into public.billing_plans (id, title, price_monthly, ai_limit, features)
values
  ('start', 'Старт', 12, 50, '["Безлимит релизов","Базовая аналитика","Чек-лист запуска","50 AI генераций","Базовый DNK"]'::jsonb),
  ('breakthrough', 'Прорыв', 24, 300, '["Все из Старт","Промо-заявки","DSP питчинг","300 AI генераций","Сплиты","Расширенная аналитика","Content Kit"]'::jsonb),
  ('empire', 'Империя', 59, 1500, '["Все из Прорыв","CRM","Команда","Мультиартист","1500 AI","Приоритет обработки"]'::jsonb)
on conflict (id) do update
set
  title = excluded.title,
  price_monthly = excluded.price_monthly,
  ai_limit = excluded.ai_limit,
  features = excluded.features;

-- ------------------------------------------------------------
-- Subscriptions (new source of truth for trial/period/status)
-- ------------------------------------------------------------
create table if not exists public.billing_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id text not null references public.billing_plans(id),
  status text not null default 'trial' check (status in ('trial', 'active', 'past_due', 'expired', 'canceled')),
  current_period_start timestamptz not null default now(),
  current_period_end timestamptz not null,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uniq_billing_subscriptions_user
  on public.billing_subscriptions(user_id);
create index if not exists idx_billing_subscriptions_status_end
  on public.billing_subscriptions(status, current_period_end);

drop trigger if exists trg_billing_subscriptions_updated_at on public.billing_subscriptions;
create trigger trg_billing_subscriptions_updated_at
before update on public.billing_subscriptions
for each row execute procedure public.set_updated_at();

-- ------------------------------------------------------------
-- Profiles compatibility fields
-- ------------------------------------------------------------
alter table public.profiles
  add column if not exists plan_id text not null default 'start',
  add column if not exists subscription_status text not null default 'trial',
  add column if not exists subscription_end timestamptz null;

-- ------------------------------------------------------------
-- AI usage per calendar month
-- ------------------------------------------------------------
create table if not exists public.billing_ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  period_start date not null default date_trunc('month', now())::date,
  used_count int not null default 0 check (used_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, period_start)
);

drop trigger if exists trg_billing_ai_usage_updated_at on public.billing_ai_usage;
create trigger trg_billing_ai_usage_updated_at
before update on public.billing_ai_usage
for each row execute procedure public.set_updated_at();

-- ------------------------------------------------------------
-- Plan helpers
-- ------------------------------------------------------------
create or replace function public.normalize_plan_slug(p_plan text)
returns text
language sql
immutable
as $$
  select case lower(coalesce(trim(p_plan), ''))
    when 'start' then 'start'
    when 'старт' then 'start'
    when 'breakthrough' then 'breakthrough'
    when 'прорыв' then 'breakthrough'
    when 'empire' then 'empire'
    when 'империя' then 'empire'
    when 'base' then 'start'
    when 'basic' then 'start'
    when 'pro' then 'breakthrough'
    when 'studio' then 'empire'
    else 'start'
  end
$$;

create or replace function public.billing_plan_rank(p_plan text)
returns int
language sql
immutable
as $$
  select case public.normalize_plan_slug(p_plan)
    when 'start' then 1
    when 'breakthrough' then 2
    when 'empire' then 3
    else 0
  end
$$;

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

  select bs.plan_id
    into v_plan
  from public.billing_subscriptions bs
  where bs.user_id = p_user
    and bs.status in ('active', 'trial')
    and bs.current_period_end > now()
  order by bs.updated_at desc nulls last, bs.created_at desc
  limit 1;

  if v_plan is null then
    select coalesce(nullif(p.plan_id, ''), p.plan, 'start')
      into v_plan
    from public.profiles p
    where p.user_id = p_user
      and coalesce(p.subscription_status, 'trial') in ('active', 'trial')
      and coalesce(p.subscription_end, now() + interval '1 day') > now()
    limit 1;
  end if;

  if v_plan is null then
    return false;
  end if;

  return public.billing_plan_rank(v_plan) >= v_required;
end;
$$;

-- ------------------------------------------------------------
-- Sync profile <- billing_subscriptions
-- ------------------------------------------------------------
create or replace function public.billing_sync_profile_from_subscription()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set
    plan_id = public.normalize_plan_slug(new.plan_id),
    plan = public.normalize_plan_slug(new.plan_id),
    subscription_status = new.status,
    subscription_end = new.current_period_end,
    updated_at = now()
  where user_id = new.user_id;
  return new;
end;
$$;

drop trigger if exists trg_billing_sync_profile on public.billing_subscriptions;
create trigger trg_billing_sync_profile
after insert or update of plan_id, status, current_period_end
on public.billing_subscriptions
for each row execute procedure public.billing_sync_profile_from_subscription();

-- ------------------------------------------------------------
-- Default trial on signup (7 days, plan breakthrough)
-- ------------------------------------------------------------
create or replace function public.create_trial_subscription_for_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.billing_subscriptions (
    user_id,
    plan_id,
    status,
    current_period_start,
    current_period_end
  )
  values (
    new.user_id,
    'breakthrough',
    'trial',
    now(),
    now() + interval '7 day'
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_profiles_create_trial_subscription on public.profiles;
create trigger trg_profiles_create_trial_subscription
after insert on public.profiles
for each row execute procedure public.create_trial_subscription_for_profile();

-- Backfill existing users without billing row
insert into public.billing_subscriptions (
  user_id,
  plan_id,
  status,
  current_period_start,
  current_period_end
)
select
  p.user_id,
  public.normalize_plan_slug(coalesce(nullif(p.plan_id, ''), p.plan, 'start')) as plan_id,
  case
    when coalesce(p.subscription_status, 'active') in ('trial', 'active', 'past_due', 'expired', 'canceled')
      then coalesce(p.subscription_status, 'active')
    else 'active'
  end as status,
  now(),
  coalesce(p.subscription_end, now() + interval '30 day') as current_period_end
from public.profiles p
where not exists (
  select 1 from public.billing_subscriptions bs where bs.user_id = p.user_id
);

-- ------------------------------------------------------------
-- Legacy compatibility with public.subscriptions (if present)
-- ------------------------------------------------------------
create or replace function public.sync_legacy_subscriptions_from_billing()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
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

drop trigger if exists trg_billing_sync_legacy_subscriptions on public.billing_subscriptions;
create trigger trg_billing_sync_legacy_subscriptions
after insert or update of plan_id, status
on public.billing_subscriptions
for each row execute procedure public.sync_legacy_subscriptions_from_billing();

create or replace function public.sync_billing_from_legacy_subscriptions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.billing_subscriptions (
    user_id, plan_id, status, current_period_start, current_period_end
  )
  values (
    new.user_id,
    public.normalize_plan_slug(new.plan),
    case
      when new.status = 'active' then 'active'
      when new.status = 'past_due' then 'past_due'
      when new.status = 'canceled' then 'canceled'
      else 'expired'
    end,
    now(),
    coalesce(
      (select subscription_end from public.profiles p where p.user_id = new.user_id),
      now() + interval '30 day'
    )
  )
  on conflict (user_id) do update
  set
    plan_id = excluded.plan_id,
    status = excluded.status,
    updated_at = now();
  return new;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'subscriptions'
  ) then
    drop trigger if exists trg_legacy_subscriptions_sync_billing on public.subscriptions;
    create trigger trg_legacy_subscriptions_sync_billing
    after insert or update of plan, status
    on public.subscriptions
    for each row execute procedure public.sync_billing_from_legacy_subscriptions();
  end if;
end $$;

-- ------------------------------------------------------------
-- Expiration job
-- ------------------------------------------------------------
create or replace function public.expire_subscriptions()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := 0;
begin
  update public.billing_subscriptions bs
  set
    status = 'expired',
    updated_at = now()
  where bs.status in ('active', 'trial')
    and bs.current_period_end <= now();

  get diagnostics v_count = row_count;

  update public.profiles p
  set
    subscription_status = bs.status,
    subscription_end = bs.current_period_end,
    plan_id = public.normalize_plan_slug(bs.plan_id),
    plan = public.normalize_plan_slug(bs.plan_id),
    updated_at = now()
  from public.billing_subscriptions bs
  where bs.user_id = p.user_id;

  return v_count;
end;
$$;

-- ------------------------------------------------------------
-- AI limit helpers
-- ------------------------------------------------------------
create or replace function public.can_consume_ai_generation(p_user uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text;
  v_limit int := 0;
  v_used int := 0;
  v_period date := date_trunc('month', now())::date;
begin
  if p_user is null then
    return false;
  end if;

  select bs.plan_id
    into v_plan
  from public.billing_subscriptions bs
  where bs.user_id = p_user
    and bs.status in ('active', 'trial')
    and bs.current_period_end > now()
  order by bs.updated_at desc nulls last, bs.created_at desc
  limit 1;

  if v_plan is null then
    v_plan := 'start';
  end if;

  select bp.ai_limit into v_limit
  from public.billing_plans bp
  where bp.id = public.normalize_plan_slug(v_plan)
  limit 1;

  select coalesce(u.used_count, 0) into v_used
  from public.billing_ai_usage u
  where u.user_id = p_user and u.period_start = v_period;

  return coalesce(v_used, 0) < coalesce(v_limit, 0);
end;
$$;

create or replace function public.consume_ai_generation(p_user uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period date := date_trunc('month', now())::date;
begin
  if not public.can_consume_ai_generation(p_user) then
    return false;
  end if;

  insert into public.billing_ai_usage (user_id, period_start, used_count)
  values (p_user, v_period, 1)
  on conflict (user_id, period_start) do update
  set
    used_count = public.billing_ai_usage.used_count + 1,
    updated_at = now();

  return true;
end;
$$;

create or replace function public.trg_consume_ai_generation_from_tool_result()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.consume_ai_generation(new.user_id) then
    raise exception 'AI generation limit reached for current plan';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ai_tool_results_consume_ai on public.ai_tool_results;
create trigger trg_ai_tool_results_consume_ai
before insert on public.ai_tool_results
for each row execute procedure public.trg_consume_ai_generation_from_tool_result();

-- ------------------------------------------------------------
-- RLS: billing tables
-- ------------------------------------------------------------
alter table public.billing_plans enable row level security;
alter table public.billing_subscriptions enable row level security;
alter table public.billing_ai_usage enable row level security;

drop policy if exists billing_plans_read_all on public.billing_plans;
create policy billing_plans_read_all on public.billing_plans
for select using (auth.uid() is not null);

drop policy if exists billing_plans_admin_manage on public.billing_plans;
create policy billing_plans_admin_manage on public.billing_plans
for all using (public.is_admin_user()) with check (public.is_admin_user());

drop policy if exists billing_subscriptions_owner_read on public.billing_subscriptions;
create policy billing_subscriptions_owner_read on public.billing_subscriptions
for select using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists billing_subscriptions_admin_manage on public.billing_subscriptions;
create policy billing_subscriptions_admin_manage on public.billing_subscriptions
for all using (public.is_admin_user()) with check (public.is_admin_user());

drop policy if exists billing_ai_usage_owner_read on public.billing_ai_usage;
create policy billing_ai_usage_owner_read on public.billing_ai_usage
for select using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists billing_ai_usage_admin_manage on public.billing_ai_usage;
create policy billing_ai_usage_admin_manage on public.billing_ai_usage
for all using (public.is_admin_user()) with check (public.is_admin_user());

-- ------------------------------------------------------------
-- RLS: feature gating
-- ------------------------------------------------------------

-- Promo requests: requires breakthrough+
drop policy if exists promo_requests_owner_insert on public.promo_requests;
create policy promo_requests_owner_insert
  on public.promo_requests
  for insert
  with check (
    user_id = auth.uid()
    and public.has_active_subscription(auth.uid(), 'breakthrough')
    and exists (
      select 1
      from public.releases r
      where r.id = promo_requests.release_id
        and r.owner_id = auth.uid()
    )
  );

-- DNK Pro sessions: requires breakthrough+
drop policy if exists dnk_test_sessions_insert_own on public.dnk_test_sessions;
create policy dnk_test_sessions_insert_own on public.dnk_test_sessions
for insert with check (
  user_id = auth.uid()
  and public.has_active_subscription(auth.uid(), 'breakthrough')
);

-- CRM read access for artist: empire only (admin still full)
drop policy if exists crm_leads_owner_read on public.crm_leads;
create policy crm_leads_owner_read on public.crm_leads
for select
using (
  public.is_admin_user()
  or (user_id = auth.uid() and public.has_active_subscription(auth.uid(), 'empire'))
);

drop policy if exists crm_deals_owner_read on public.crm_deals;
create policy crm_deals_owner_read on public.crm_deals
for select
using (
  public.is_admin_user()
  or (user_id = auth.uid() and public.has_active_subscription(auth.uid(), 'empire'))
);

drop policy if exists crm_tasks_read on public.crm_tasks;
create policy crm_tasks_read on public.crm_tasks
for select
using (
  public.is_admin_user()
  or (
    public.has_active_subscription(auth.uid(), 'empire')
    and exists (
      select 1 from public.crm_leads l
      where l.id = crm_tasks.lead_id and l.user_id = auth.uid()
    )
  )
  or (
    public.has_active_subscription(auth.uid(), 'empire')
    and exists (
      select 1 from public.crm_deals d
      where d.id = crm_tasks.deal_id and d.user_id = auth.uid()
    )
  )
);

drop policy if exists crm_notes_read on public.crm_notes;
create policy crm_notes_read on public.crm_notes
for select
using (
  public.is_admin_user()
  or (
    user_id = auth.uid()
    and public.has_active_subscription(auth.uid(), 'empire')
  )
);

drop policy if exists crm_events_read on public.crm_events;
create policy crm_events_read on public.crm_events
for select
using (
  public.is_admin_user()
  or (
    public.has_active_subscription(auth.uid(), 'empire')
    and exists (
      select 1 from public.crm_leads l
      where l.id = crm_events.lead_id and l.user_id = auth.uid()
    )
  )
  or (
    public.has_active_subscription(auth.uid(), 'empire')
    and exists (
      select 1 from public.crm_deals d
      where d.id = crm_events.deal_id and d.user_id = auth.uid()
    )
  )
);

drop policy if exists crm_invoices_owner_read on public.crm_invoices;
create policy crm_invoices_owner_read on public.crm_invoices
for select
using (
  public.is_admin_user()
  or (user_id = auth.uid() and public.has_active_subscription(auth.uid(), 'empire'))
);

drop policy if exists crm_transactions_owner_read on public.crm_transactions;
create policy crm_transactions_owner_read on public.crm_transactions
for select
using (
  public.is_admin_user()
  or (user_id = auth.uid() and public.has_active_subscription(auth.uid(), 'empire'))
);

-- AI results insert with limit check
drop policy if exists ai_tool_results_insert_own on public.ai_tool_results;
create policy ai_tool_results_insert_own on public.ai_tool_results
for insert
with check (
  auth.uid() = user_id
  and public.can_consume_ai_generation(auth.uid())
);

commit;

