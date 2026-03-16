-- ============================================================
-- 043 · Support SLA and escalations
-- ============================================================

alter table public.support_tickets
  add column if not exists first_response_at timestamptz,
  add column if not exists resolved_at timestamptz,
  add column if not exists due_at timestamptz,
  add column if not exists escalation_level int not null default 0;

create index if not exists idx_support_tickets_due on public.support_tickets(status, due_at);
create index if not exists idx_support_tickets_escalation on public.support_tickets(escalation_level, updated_at desc);

create or replace function public.support_apply_status_timestamps()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if new.status = 'in_progress' and old.status <> 'in_progress' and new.first_response_at is null then
      new.first_response_at = now();
    end if;
    if new.status = 'resolved' and old.status <> 'resolved' then
      new.resolved_at = now();
    end if;
    if new.status in ('open', 'in_progress') and new.due_at is null then
      -- simple SLA default: 48h from now
      new.due_at = now() + interval '48 hours';
    end if;
    if new.status = 'open' and old.status in ('resolved', 'closed') then
      new.resolved_at = null;
      new.first_response_at = null;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_support_apply_status_timestamps on public.support_tickets;
create trigger trg_support_apply_status_timestamps
before update on public.support_tickets
for each row execute procedure public.support_apply_status_timestamps();

create or replace view public.support_sla_view as
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
