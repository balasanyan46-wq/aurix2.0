-- ============================================================
-- 049 · CRM events insert policy for artist-side notes
-- ============================================================

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'crm_events'
  ) then
    alter table public.crm_events enable row level security;

    drop policy if exists crm_events_owner_insert on public.crm_events;
    create policy crm_events_owner_insert on public.crm_events
    for insert
    with check (
      public.is_admin_user()
      or exists (
        select 1
        from public.crm_leads l
        where l.id = crm_events.lead_id
          and l.user_id = auth.uid()
      )
      or exists (
        select 1
        from public.crm_deals d
        where d.id = crm_events.deal_id
          and d.user_id = auth.uid()
      )
    );

    drop policy if exists crm_events_admin_delete on public.crm_events;
    create policy crm_events_admin_delete on public.crm_events
    for delete
    using (public.is_admin_user());
  end if;
end $$;
