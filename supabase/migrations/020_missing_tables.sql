-- =============================================
-- team_members
-- =============================================
create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  member_name text not null default '',
  member_email text,
  role text not null default 'producer',
  split_percent decimal(5,2) not null default 0,
  status text not null default 'active' check (status in ('active', 'removed')),
  created_at timestamptz default now()
);

create index if not exists idx_team_members_owner on public.team_members(owner_id);

alter table public.team_members enable row level security;

create policy "Users manage own team"
  on public.team_members for select
  using (auth.uid() = owner_id);

create policy "Users insert own team"
  on public.team_members for insert
  with check (auth.uid() = owner_id);

create policy "Users update own team"
  on public.team_members for update
  using (auth.uid() = owner_id);

-- =============================================
-- legal_templates (admin-managed, all users can read)
-- =============================================
create table if not exists public.legal_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  category text not null default 'distribution',
  body text not null default '',
  schema jsonb,
  version int default 1,
  created_at timestamptz default now()
);

alter table public.legal_templates enable row level security;

create policy "Anyone can read templates"
  on public.legal_templates for select
  using (auth.uid() is not null);

create policy "Admins manage templates"
  on public.legal_templates for all
  using (
    exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin')
  );

-- =============================================
-- legal_documents (user-owned generated docs)
-- =============================================
create table if not exists public.legal_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  template_id uuid references public.legal_templates(id) on delete set null,
  template_version int default 1,
  title text not null default '',
  payload jsonb default '{}'::jsonb,
  file_pdf_path text,
  status text not null default 'draft' check (status in ('draft', 'generated', 'signed')),
  created_at timestamptz default now()
);

create index if not exists idx_legal_documents_user on public.legal_documents(user_id);

alter table public.legal_documents enable row level security;

create policy "Users read own documents"
  on public.legal_documents for select
  using (auth.uid() = user_id);

create policy "Users create own documents"
  on public.legal_documents for insert
  with check (auth.uid() = user_id);

create policy "Users update own documents"
  on public.legal_documents for update
  using (auth.uid() = user_id);

-- =============================================
-- Storage bucket for legal PDFs
-- =============================================
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "Users upload own legal docs"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users read own legal docs"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- =============================================
-- RLS: allow users to see their own report_rows
-- (via track_id -> tracks -> releases -> owner_id)
-- =============================================
create policy "Users read own report rows" on public.report_rows
  for select using (
    exists (
      select 1 from public.tracks t
      join public.releases r on r.id = t.release_id
      where t.id = report_rows.track_id
        and r.owner_id = auth.uid()
    )
    or exists (
      select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin'
    )
  );

-- Allow users to see reports that contain their rows
create policy "Users read related reports" on public.reports
  for select using (
    exists (
      select 1 from public.report_rows rr
      join public.tracks t on t.id = rr.track_id
      join public.releases rel on rel.id = t.release_id
      where rr.report_id = reports.id
        and rel.owner_id = auth.uid()
    )
    or exists (
      select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin'
    )
  );

-- =============================================
-- Seed: sample legal templates
-- =============================================
insert into public.legal_templates (title, description, category, body, schema) values
(
  'Договор дистрибуции',
  'Стандартный договор между артистом и дистрибьютором',
  'distribution',
  E'ДОГОВОР ДИСТРИБУЦИИ\n\nг. {{CITY}}, {{DATE}}\n\nАртист: {{ARTIST_NAME}}\nТелефон: {{PHONE}}\n\n1. ПРЕДМЕТ ДОГОВОРА\nДистрибьютор обязуется осуществлять цифровую дистрибуцию музыкальных произведений Артиста на все основные стриминговые платформы.\n\n2. СРОК ДЕЙСТВИЯ\nНастоящий договор вступает в силу с даты подписания и действует в течение 1 (одного) года.\n\n3. ПРАВА И ОБЯЗАННОСТИ\n3.1. Артист сохраняет 100% авторских прав на произведения.\n3.2. Дистрибьютор обязуется обеспечить размещение на площадках в течение 5 рабочих дней.\n\n4. ФИНАНСОВЫЕ УСЛОВИЯ\nАртист получает {{REVENUE_SHARE}}% от чистого дохода.\n\nПодпись Артиста: _______________\nДата: {{DATE}}',
  '["ARTIST_NAME", "CITY", "DATE", "PHONE", "REVENUE_SHARE"]'::jsonb
),
(
  'NDA (Соглашение о неразглашении)',
  'Соглашение о конфиденциальности для участников проекта',
  'nda',
  E'СОГЛАШЕНИЕ О НЕРАЗГЛАШЕНИИ\n\nг. {{CITY}}, {{DATE}}\n\nСторона 1 (Раскрывающая): {{ARTIST_NAME}}\nСторона 2 (Получающая): {{PARTNER_NAME}}\n\n1. Получающая сторона обязуется не разглашать конфиденциальную информацию, включая:\n- Неопубликованные музыкальные произведения\n- Финансовые условия сотрудничества\n- Планы релизов и маркетинга\n\n2. Срок действия: {{NDA_PERIOD}} месяцев с даты подписания.\n\n3. Штраф за нарушение: {{PENALTY}} руб.\n\nПодпись: _______________\nДата: {{DATE}}',
  '["ARTIST_NAME", "CITY", "DATE", "PARTNER_NAME", "NDA_PERIOD", "PENALTY"]'::jsonb
),
(
  'Договор с продюсером',
  'Договор между артистом и продюсером на производство трека',
  'production',
  E'ДОГОВОР НА ПРОИЗВОДСТВО\n\nг. {{CITY}}, {{DATE}}\n\nАртист: {{ARTIST_NAME}}\nПродюсер: {{PRODUCER_NAME}}\n\n1. Продюсер обязуется произвести запись, сведение и мастеринг трека «{{TRACK_TITLE}}».\n\n2. Сроки: завершение работ до {{DEADLINE}}.\n\n3. Оплата: {{PAYMENT}} руб.\n   Аванс: {{ADVANCE}}%\n   Остаток после приёмки.\n\n4. Авторские права:\n   Артист — {{ARTIST_SHARE}}%\n   Продюсер — {{PRODUCER_SHARE}}%\n\nПодписи: _______________',
  '["ARTIST_NAME", "CITY", "DATE", "PRODUCER_NAME", "TRACK_TITLE", "DEADLINE", "PAYMENT", "ADVANCE", "ARTIST_SHARE", "PRODUCER_SHARE"]'::jsonb
),
(
  'Договор с участником команды',
  'Оформление сотрудничества с менеджером, дизайнером или звукорежиссёром',
  'team',
  E'ДОГОВОР ОКАЗАНИЯ УСЛУГ\n\nг. {{CITY}}, {{DATE}}\n\nЗаказчик: {{ARTIST_NAME}}\nИсполнитель: {{TEAM_MEMBER_NAME}}\nРоль: {{ROLE}}\n\n1. Исполнитель оказывает услуги в рамках проекта Заказчика.\n\n2. Вознаграждение: {{PAYMENT}} руб. / {{REVENUE_SHARE}}% от доходов.\n\n3. Срок: с {{START_DATE}} по {{END_DATE}}.\n\nПодписи: _______________',
  '["ARTIST_NAME", "CITY", "DATE", "TEAM_MEMBER_NAME", "ROLE", "PAYMENT", "REVENUE_SHARE", "START_DATE", "END_DATE"]'::jsonb
)
on conflict do nothing;
