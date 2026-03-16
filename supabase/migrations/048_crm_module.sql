-- ============================================================
-- 048 · CRM module (leads/deals/tasks/notes/events)
-- ============================================================

create table if not exists public.crm_leads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid null references public.releases(id) on delete set null,
  source text not null check (source in ('promo', 'pitch', 'influencer', 'ads', 'support', 'other')),
  type text null,
  pipeline_stage text not null default 'new'
    check (pipeline_stage in ('new', 'in_work', 'need_info', 'offer_sent', 'paid', 'production', 'done', 'archived')),
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high')),
  assigned_to uuid null references auth.users(id) on delete set null,
  due_at timestamptz null,
  title text null,
  description text null,
  promo_request_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_deals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release_id uuid null references public.releases(id) on delete set null,
  lead_id uuid null references public.crm_leads(id) on delete set null,
  status text not null default 'draft' check (status in ('draft', 'active', 'completed', 'canceled')),
  amount numeric null,
  currency text not null default 'RUB',
  package_title text null,
  started_at timestamptz null,
  deadline_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_tasks (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid null references public.crm_leads(id) on delete cascade,
  deal_id uuid null references public.crm_deals(id) on delete cascade,
  assigned_to uuid null references auth.users(id) on delete set null,
  title text not null,
  status text not null default 'open' check (status in ('open', 'done')),
  due_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint crm_tasks_target_chk check (lead_id is not null or deal_id is not null)
);

create table if not exists public.crm_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  lead_id uuid null references public.crm_leads(id) on delete cascade,
  deal_id uuid null references public.crm_deals(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now(),
  constraint crm_notes_target_chk check (lead_id is not null or deal_id is not null)
);

create table if not exists public.crm_events (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid null references public.crm_leads(id) on delete cascade,
  deal_id uuid null references public.crm_deals(id) on delete cascade,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint crm_events_target_chk check (lead_id is not null or deal_id is not null)
);

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'promo_requests'
  ) then
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public' and table_name = 'crm_leads' and column_name = 'promo_request_id'
    ) then
      alter table public.crm_leads add column promo_request_id uuid null;
    end if;
    alter table public.crm_leads
      drop constraint if exists crm_leads_promo_request_fkey;
    alter table public.crm_leads
      add constraint crm_leads_promo_request_fkey
      foreign key (promo_request_id) references public.promo_requests(id) on delete set null;
  end if;
end $$;

create unique index if not exists uniq_crm_leads_promo_request
  on public.crm_leads(promo_request_id)
  where promo_request_id is not null;

create index if not exists idx_crm_leads_user on public.crm_leads(user_id, created_at desc);
create index if not exists idx_crm_leads_stage on public.crm_leads(pipeline_stage, priority, due_at);
create index if not exists idx_crm_leads_assigned on public.crm_leads(assigned_to, due_at);
create index if not exists idx_crm_deals_user on public.crm_deals(user_id, created_at desc);
create index if not exists idx_crm_deals_status on public.crm_deals(status, deadline_at);
create index if not exists idx_crm_tasks_assigned on public.crm_tasks(assigned_to, status, due_at);
create index if not exists idx_crm_tasks_lead on public.crm_tasks(lead_id);
create index if not exists idx_crm_notes_user on public.crm_notes(user_id, created_at desc);
create index if not exists idx_crm_events_lead on public.crm_events(lead_id, created_at desc);
create index if not exists idx_crm_events_deal on public.crm_events(deal_id, created_at desc);

create or replace function public.crm_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_crm_leads_updated_at on public.crm_leads;
create trigger trg_crm_leads_updated_at
before update on public.crm_leads
for each row execute procedure public.crm_set_updated_at();

drop trigger if exists trg_crm_deals_updated_at on public.crm_deals;
create trigger trg_crm_deals_updated_at
before update on public.crm_deals
for each row execute procedure public.crm_set_updated_at();

drop trigger if exists trg_crm_tasks_updated_at on public.crm_tasks;
create trigger trg_crm_tasks_updated_at
before update on public.crm_tasks
for each row execute procedure public.crm_set_updated_at();

create or replace function public.crm_map_stage_from_promo(p_status text)
returns text
language sql
immutable
as $$
  select case p_status
    when 'approved' then 'in_work'
    when 'under_review' then 'in_work'
    when 'in_progress' then 'production'
    when 'completed' then 'done'
    when 'rejected' then 'archived'
    else 'new'
  end
$$;

create or replace function public.crm_sync_lead_from_promo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lead_id uuid;
  v_stage text;
begin
  v_stage := public.crm_map_stage_from_promo(new.status::text);

  insert into public.crm_leads (
    user_id,
    release_id,
    source,
    type,
    pipeline_stage,
    priority,
    assigned_to,
    title,
    description,
    promo_request_id
  )
  values (
    new.user_id,
    new.release_id,
    'promo',
    new.type::text,
    v_stage,
    'normal',
    new.assigned_manager,
    concat('Промо заявка · ', new.type::text),
    coalesce(new.admin_notes, ''),
    new.id
  )
  on conflict (promo_request_id) where promo_request_id is not null do update set
    user_id = excluded.user_id,
    release_id = excluded.release_id,
    type = excluded.type,
    assigned_to = excluded.assigned_to,
    description = excluded.description,
    pipeline_stage = excluded.pipeline_stage,
    updated_at = now()
  returning id into v_lead_id;

  insert into public.crm_events(lead_id, event_type, payload)
  values (
    v_lead_id,
    case when tg_op = 'INSERT' then 'promo_synced' else 'promo_updated' end,
    jsonb_build_object(
      'promo_request_id', new.id,
      'promo_status', new.status,
      'promo_type', new.type
    )
  );

  return new;
end;
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'promo_requests'
  ) then
    drop trigger if exists trg_crm_sync_from_promo on public.promo_requests;
    create trigger trg_crm_sync_from_promo
    after insert or update of status, assigned_manager, admin_notes, form_data, release_id, type
    on public.promo_requests
    for each row execute procedure public.crm_sync_lead_from_promo();

    insert into public.crm_leads (
      user_id,
      release_id,
      source,
      type,
      pipeline_stage,
      priority,
      assigned_to,
      title,
      description,
      promo_request_id
    )
    select
      pr.user_id,
      pr.release_id,
      'promo',
      pr.type::text,
      public.crm_map_stage_from_promo(pr.status::text),
      'normal',
      pr.assigned_manager,
      concat('Промо заявка · ', pr.type::text),
      coalesce(pr.admin_notes, ''),
      pr.id
    from public.promo_requests pr
    on conflict (promo_request_id) where promo_request_id is not null do update set
      user_id = excluded.user_id,
      release_id = excluded.release_id,
      type = excluded.type,
      assigned_to = excluded.assigned_to,
      description = excluded.description,
      pipeline_stage = excluded.pipeline_stage,
      updated_at = now();
  end if;
end $$;

alter table public.crm_leads enable row level security;
alter table public.crm_deals enable row level security;
alter table public.crm_tasks enable row level security;
alter table public.crm_notes enable row level security;
alter table public.crm_events enable row level security;

drop policy if exists crm_leads_owner_read on public.crm_leads;
create policy crm_leads_owner_read on public.crm_leads
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists crm_leads_owner_insert on public.crm_leads;
create policy crm_leads_owner_insert on public.crm_leads
for insert
with check (user_id = auth.uid() or public.is_admin_user());

drop policy if exists crm_leads_admin_update on public.crm_leads;
create policy crm_leads_admin_update on public.crm_leads
for update
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists crm_leads_admin_delete on public.crm_leads;
create policy crm_leads_admin_delete on public.crm_leads
for delete
using (public.is_admin_user());

drop policy if exists crm_deals_owner_read on public.crm_deals;
create policy crm_deals_owner_read on public.crm_deals
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists crm_deals_admin_insert on public.crm_deals;
create policy crm_deals_admin_insert on public.crm_deals
for insert
with check (public.is_admin_user());

drop policy if exists crm_deals_admin_update on public.crm_deals;
create policy crm_deals_admin_update on public.crm_deals
for update
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists crm_deals_admin_delete on public.crm_deals;
create policy crm_deals_admin_delete on public.crm_deals
for delete
using (public.is_admin_user());

drop policy if exists crm_tasks_read on public.crm_tasks;
create policy crm_tasks_read on public.crm_tasks
for select
using (
  public.is_admin_user()
  or assigned_to = auth.uid()
  or exists (
    select 1 from public.crm_leads l
    where l.id = crm_tasks.lead_id and l.user_id = auth.uid()
  )
  or exists (
    select 1 from public.crm_deals d
    where d.id = crm_tasks.deal_id and d.user_id = auth.uid()
  )
);

drop policy if exists crm_tasks_admin_insert on public.crm_tasks;
create policy crm_tasks_admin_insert on public.crm_tasks
for insert
with check (public.is_admin_user());

drop policy if exists crm_tasks_admin_update on public.crm_tasks;
create policy crm_tasks_admin_update on public.crm_tasks
for update
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists crm_tasks_admin_delete on public.crm_tasks;
create policy crm_tasks_admin_delete on public.crm_tasks
for delete
using (public.is_admin_user());

drop policy if exists crm_notes_read on public.crm_notes;
create policy crm_notes_read on public.crm_notes
for select
using (
  public.is_admin_user()
  or user_id = auth.uid()
);

drop policy if exists crm_notes_insert on public.crm_notes;
create policy crm_notes_insert on public.crm_notes
for insert
with check (
  public.is_admin_user()
  or (user_id = auth.uid() and author_id = auth.uid())
);

drop policy if exists crm_notes_admin_update on public.crm_notes;
create policy crm_notes_admin_update on public.crm_notes
for update
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists crm_notes_admin_delete on public.crm_notes;
create policy crm_notes_admin_delete on public.crm_notes
for delete
using (public.is_admin_user());

drop policy if exists crm_events_read on public.crm_events;
create policy crm_events_read on public.crm_events
for select
using (
  public.is_admin_user()
  or exists (
    select 1 from public.crm_leads l
    where l.id = crm_events.lead_id and l.user_id = auth.uid()
  )
  or exists (
    select 1 from public.crm_deals d
    where d.id = crm_events.deal_id and d.user_id = auth.uid()
  )
);

drop policy if exists crm_events_admin_insert on public.crm_events;
create policy crm_events_admin_insert on public.crm_events
for insert
with check (public.is_admin_user());

drop policy if exists crm_events_admin_update on public.crm_events;
create policy crm_events_admin_update on public.crm_events
for update
using (public.is_admin_user())
with check (public.is_admin_user());

