-- ============================================================
-- 050 · CRM full big-bang (support + production + finance)
-- ============================================================

-- ---------- CRM links extension ----------
alter table public.crm_leads
  add column if not exists support_ticket_id uuid null,
  add column if not exists production_order_id uuid null,
  add column if not exists production_item_id uuid null;

alter table public.crm_deals
  add column if not exists production_order_id uuid null,
  add column if not exists production_item_id uuid null;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'support_tickets'
  ) then
    alter table public.crm_leads
      drop constraint if exists crm_leads_support_ticket_fkey;
    alter table public.crm_leads
      add constraint crm_leads_support_ticket_fkey
      foreign key (support_ticket_id) references public.support_tickets(id) on delete set null;
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'production_orders'
  ) then
    alter table public.crm_leads
      drop constraint if exists crm_leads_production_order_fkey;
    alter table public.crm_leads
      add constraint crm_leads_production_order_fkey
      foreign key (production_order_id) references public.production_orders(id) on delete set null;

    alter table public.crm_deals
      drop constraint if exists crm_deals_production_order_fkey;
    alter table public.crm_deals
      add constraint crm_deals_production_order_fkey
      foreign key (production_order_id) references public.production_orders(id) on delete set null;
  end if;

  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'production_order_items'
  ) then
    alter table public.crm_leads
      drop constraint if exists crm_leads_production_item_fkey;
    alter table public.crm_leads
      add constraint crm_leads_production_item_fkey
      foreign key (production_item_id) references public.production_order_items(id) on delete set null;

    alter table public.crm_deals
      drop constraint if exists crm_deals_production_item_fkey;
    alter table public.crm_deals
      add constraint crm_deals_production_item_fkey
      foreign key (production_item_id) references public.production_order_items(id) on delete set null;
  end if;
end $$;

create unique index if not exists uniq_crm_leads_support_ticket
  on public.crm_leads(support_ticket_id)
  where support_ticket_id is not null;

create unique index if not exists uniq_crm_deals_production_order
  on public.crm_deals(production_order_id)
  where production_order_id is not null;

create index if not exists idx_crm_leads_support_ticket on public.crm_leads(support_ticket_id);
create index if not exists idx_crm_leads_production_order on public.crm_leads(production_order_id);
create index if not exists idx_crm_deals_production_order on public.crm_deals(production_order_id);

-- ---------- Finance tables ----------
create table if not exists public.crm_invoices (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references public.crm_deals(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null check (amount >= 0),
  currency text not null default 'RUB',
  status text not null default 'draft'
    check (status in ('draft', 'sent', 'paid', 'overdue', 'canceled')),
  due_at timestamptz null,
  paid_at timestamptz null,
  external_ref text null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_transactions (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.crm_invoices(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null check (amount >= 0),
  provider text not null default 'manual',
  status text not null default 'pending'
    check (status in ('pending', 'succeeded', 'failed', 'refunded')),
  paid_at timestamptz null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_crm_invoices_deal on public.crm_invoices(deal_id, created_at desc);
create index if not exists idx_crm_invoices_user on public.crm_invoices(user_id, created_at desc);
create index if not exists idx_crm_invoices_status on public.crm_invoices(status, due_at);
create index if not exists idx_crm_txn_invoice on public.crm_transactions(invoice_id, created_at desc);
create index if not exists idx_crm_txn_user on public.crm_transactions(user_id, created_at desc);
create index if not exists idx_crm_txn_status on public.crm_transactions(status, paid_at);

drop trigger if exists trg_crm_invoices_updated_at on public.crm_invoices;
create trigger trg_crm_invoices_updated_at
before update on public.crm_invoices
for each row execute procedure public.crm_set_updated_at();

alter table public.crm_invoices enable row level security;
alter table public.crm_transactions enable row level security;

drop policy if exists crm_invoices_owner_read on public.crm_invoices;
create policy crm_invoices_owner_read on public.crm_invoices
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists crm_invoices_admin_insert on public.crm_invoices;
create policy crm_invoices_admin_insert on public.crm_invoices
for insert
with check (public.is_admin_user());

drop policy if exists crm_invoices_admin_update on public.crm_invoices;
create policy crm_invoices_admin_update on public.crm_invoices
for update
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists crm_invoices_admin_delete on public.crm_invoices;
create policy crm_invoices_admin_delete on public.crm_invoices
for delete
using (public.is_admin_user());

drop policy if exists crm_transactions_owner_read on public.crm_transactions;
create policy crm_transactions_owner_read on public.crm_transactions
for select
using (user_id = auth.uid() or public.is_admin_user());

drop policy if exists crm_transactions_admin_insert on public.crm_transactions;
create policy crm_transactions_admin_insert on public.crm_transactions
for insert
with check (public.is_admin_user());

drop policy if exists crm_transactions_admin_update on public.crm_transactions;
create policy crm_transactions_admin_update on public.crm_transactions
for update
using (public.is_admin_user())
with check (public.is_admin_user());

drop policy if exists crm_transactions_admin_delete on public.crm_transactions;
create policy crm_transactions_admin_delete on public.crm_transactions
for delete
using (public.is_admin_user());

-- ---------- Status mappers ----------
create or replace function public.crm_map_stage_from_support(p_status text)
returns text
language sql
immutable
as $$
  select case p_status
    when 'open' then 'new'
    when 'in_progress' then 'in_work'
    when 'resolved' then 'done'
    when 'closed' then 'archived'
    else 'new'
  end
$$;

create or replace function public.crm_map_deal_status_from_production(
  p_order_status text,
  p_has_items boolean,
  p_all_items_done boolean
)
returns text
language sql
immutable
as $$
  select case
    when p_order_status = 'canceled' then 'canceled'
    when p_order_status = 'completed' then 'completed'
    when p_has_items and p_all_items_done then 'completed'
    else 'active'
  end
$$;

-- ---------- Support -> CRM Lead sync ----------
create or replace function public.crm_sync_lead_from_support()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lead_id uuid;
begin
  insert into public.crm_leads (
    user_id,
    source,
    type,
    pipeline_stage,
    priority,
    title,
    description,
    support_ticket_id
  )
  values (
    new.user_id,
    'support',
    new.priority::text,
    public.crm_map_stage_from_support(new.status::text),
    case new.priority::text
      when 'high' then 'high'
      when 'low' then 'low'
      else 'normal'
    end,
    concat('Support · ', new.subject),
    new.message,
    new.id
  )
  on conflict (support_ticket_id) where support_ticket_id is not null do update set
    user_id = excluded.user_id,
    type = excluded.type,
    pipeline_stage = excluded.pipeline_stage,
    priority = excluded.priority,
    title = excluded.title,
    description = excluded.description,
    updated_at = now()
  returning id into v_lead_id;

  insert into public.crm_events(lead_id, event_type, payload)
  values (
    v_lead_id,
    case when tg_op = 'INSERT' then 'support_synced' else 'support_updated' end,
    jsonb_build_object(
      'support_ticket_id', new.id,
      'support_status', new.status,
      'priority', new.priority
    )
  );

  return new;
end;
$$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'support_tickets'
  ) then
    drop trigger if exists trg_crm_sync_from_support on public.support_tickets;
    create trigger trg_crm_sync_from_support
    after insert or update of status, priority, subject, message
    on public.support_tickets
    for each row execute procedure public.crm_sync_lead_from_support();

    insert into public.crm_leads (
      user_id,
      source,
      type,
      pipeline_stage,
      priority,
      title,
      description,
      support_ticket_id
    )
    select
      t.user_id,
      'support',
      t.priority::text,
      public.crm_map_stage_from_support(t.status::text),
      case t.priority::text
        when 'high' then 'high'
        when 'low' then 'low'
        else 'normal'
      end,
      concat('Support · ', t.subject),
      t.message,
      t.id
    from public.support_tickets t
    on conflict (support_ticket_id) where support_ticket_id is not null do update set
      user_id = excluded.user_id,
      type = excluded.type,
      pipeline_stage = excluded.pipeline_stage,
      priority = excluded.priority,
      title = excluded.title,
      description = excluded.description,
      updated_at = now();
  end if;
end $$;

-- ---------- Production -> CRM Deal sync ----------
create or replace function public.crm_refresh_deal_from_production_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_count_items int := 0;
  v_done_items int := 0;
  v_amount numeric := null;
  v_deadline timestamptz := null;
  v_status text := 'active';
  v_deal_id uuid;
begin
  select *
  into v_order
  from public.production_orders o
  where o.id = p_order_id;

  if v_order.id is null then
    return null;
  end if;

  select count(*), count(*) filter (where i.status = 'done')
  into v_count_items, v_done_items
  from public.production_order_items i
  where i.order_id = p_order_id;

  select
    nullif(sum(coalesce(sc.default_price, 0)), 0),
    max(i.deadline_at)
  into v_amount, v_deadline
  from public.production_order_items i
  join public.service_catalog sc on sc.id = i.service_id
  where i.order_id = p_order_id;

  v_status := public.crm_map_deal_status_from_production(
    v_order.status::text,
    v_count_items > 0,
    v_count_items > 0 and v_done_items = v_count_items
  );

  insert into public.crm_deals (
    user_id,
    release_id,
    status,
    amount,
    currency,
    package_title,
    started_at,
    deadline_at,
    production_order_id
  )
  values (
    v_order.user_id,
    v_order.release_id,
    v_status,
    v_amount,
    'RUB',
    coalesce(v_order.title, 'Production order'),
    v_order.created_at,
    v_deadline,
    v_order.id
  )
  on conflict (production_order_id) where production_order_id is not null do update set
    user_id = excluded.user_id,
    release_id = excluded.release_id,
    status = excluded.status,
    amount = excluded.amount,
    package_title = excluded.package_title,
    deadline_at = excluded.deadline_at,
    updated_at = now()
  returning id into v_deal_id;

  return v_deal_id;
end;
$$;

create or replace function public.crm_sync_deal_from_production_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal_id uuid;
begin
  v_deal_id := public.crm_refresh_deal_from_production_order(new.id);
  if v_deal_id is not null then
    insert into public.crm_events(deal_id, event_type, payload)
    values (
      v_deal_id,
      case when tg_op = 'INSERT' then 'production_order_synced' else 'production_order_updated' end,
      jsonb_build_object(
        'production_order_id', new.id,
        'order_status', new.status
      )
    );
  end if;
  return new;
end;
$$;

create or replace function public.crm_sync_deal_from_production_item()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal_id uuid;
begin
  v_deal_id := public.crm_refresh_deal_from_production_order(new.order_id);
  if v_deal_id is not null then
    insert into public.crm_events(deal_id, event_type, payload)
    values (
      v_deal_id,
      case when tg_op = 'INSERT' then 'production_item_synced' else 'production_item_updated' end,
      jsonb_build_object(
        'production_item_id', new.id,
        'item_status', new.status
      )
    );
  end if;
  return new;
end;
$$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'production_orders'
  ) then
    drop trigger if exists trg_crm_sync_from_production_order on public.production_orders;
    create trigger trg_crm_sync_from_production_order
    after insert or update of status, title, release_id
    on public.production_orders
    for each row execute procedure public.crm_sync_deal_from_production_order();

    perform public.crm_refresh_deal_from_production_order(o.id)
    from public.production_orders o;
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'production_order_items'
  ) then
    drop trigger if exists trg_crm_sync_from_production_item on public.production_order_items;
    create trigger trg_crm_sync_from_production_item
    after insert or update of status, deadline_at, assignee_id
    on public.production_order_items
    for each row execute procedure public.crm_sync_deal_from_production_item();
  end if;
end $$;

-- ---------- Finance events ----------
create or replace function public.crm_log_invoice_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.crm_events(deal_id, event_type, payload)
  values (
    new.deal_id,
    case when tg_op = 'INSERT' then 'invoice_created' else 'invoice_updated' end,
    jsonb_build_object(
      'invoice_id', new.id,
      'status', new.status,
      'amount', new.amount,
      'currency', new.currency
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_crm_invoice_event on public.crm_invoices;
create trigger trg_crm_invoice_event
after insert or update of status, amount, currency, due_at, paid_at
on public.crm_invoices
for each row execute procedure public.crm_log_invoice_event();

create or replace function public.crm_log_transaction_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deal_id uuid;
begin
  select i.deal_id into v_deal_id
  from public.crm_invoices i
  where i.id = new.invoice_id;

  if v_deal_id is not null then
    insert into public.crm_events(deal_id, event_type, payload)
    values (
      v_deal_id,
      case
        when new.status = 'succeeded' then 'payment_confirmed'
        when new.status = 'failed' then 'payment_failed'
        when new.status = 'refunded' then 'payment_refunded'
        else 'transaction_recorded'
      end,
      jsonb_build_object(
        'transaction_id', new.id,
        'invoice_id', new.invoice_id,
        'provider', new.provider,
        'status', new.status,
        'amount', new.amount
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_crm_transaction_event on public.crm_transactions;
create trigger trg_crm_transaction_event
after insert or update of status, paid_at
on public.crm_transactions
for each row execute procedure public.crm_log_transaction_event();
