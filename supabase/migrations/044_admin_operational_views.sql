-- ============================================================
-- 044 · Admin operational views
-- ============================================================

create or replace view public.admin_ops_delete_requests_queue as
select
  status,
  count(*)::int as total,
  min(created_at) as oldest_created_at,
  max(created_at) as newest_created_at
from public.release_delete_requests
group by status;

create or replace view public.admin_ops_production_overdue as
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

create or replace view public.admin_ops_support_overdue as
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

create or replace view public.admin_ops_reports_health as
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
