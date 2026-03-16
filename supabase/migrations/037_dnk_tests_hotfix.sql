-- ============================================================
-- 037 · DNK tests hotfix (ensure tables + RLS exist)
-- ============================================================

create table if not exists public.dnk_test_defs (
  slug         text primary key,
  title_ru     text not null,
  description  text not null default '',
  example_json jsonb not null default '{}'::jsonb,
  sort_order   int not null default 0,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

create table if not exists public.dnk_test_sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  test_slug    text not null references public.dnk_test_defs(slug) on delete restrict,
  status       text not null default 'in_progress'
               check (status in ('in_progress', 'finished', 'abandoned')),
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  version      int not null default 1,
  created_at   timestamptz not null default now()
);

create table if not exists public.dnk_test_answers (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null references public.dnk_test_sessions(id) on delete cascade,
  question_id  text not null,
  answer_type  text not null check (answer_type in ('scale', 'choice', 'sjt', 'open_text')),
  answer_json  jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  unique (session_id, question_id)
);

create table if not exists public.dnk_test_results (
  id              uuid primary key default gen_random_uuid(),
  session_id      uuid not null references public.dnk_test_sessions(id) on delete cascade,
  test_slug       text not null references public.dnk_test_defs(slug) on delete restrict,
  score_axes      jsonb not null default '{}'::jsonb,
  summary         text not null default '',
  strengths       jsonb not null default '[]'::jsonb,
  risks           jsonb not null default '[]'::jsonb,
  actions_7_days  jsonb not null default '[]'::jsonb,
  content_prompts jsonb not null default '[]'::jsonb,
  payload         jsonb not null default '{}'::jsonb,
  confidence      jsonb not null default '{}'::jsonb,
  raw_features    jsonb not null default '{}'::jsonb,
  regen_count     int not null default 0,
  created_at      timestamptz not null default now()
);

create table if not exists public.dnk_test_aai_links (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references auth.users(id) on delete cascade,
  release_id              uuid references public.releases(id) on delete cascade,
  test_slug               text not null references public.dnk_test_defs(slug) on delete cascade,
  result_id               uuid references public.dnk_test_results(id) on delete cascade,
  expected_growth_channel text not null default '',
  notes                   text not null default '',
  created_at              timestamptz not null default now()
);

create index if not exists idx_dnk_test_sessions_user_test_created
  on public.dnk_test_sessions(user_id, test_slug, created_at desc);
create index if not exists idx_dnk_test_answers_session
  on public.dnk_test_answers(session_id);
create index if not exists idx_dnk_test_results_test_created
  on public.dnk_test_results(test_slug, created_at desc);
create index if not exists idx_dnk_test_results_session
  on public.dnk_test_results(session_id);
create index if not exists idx_dnk_test_aai_links_user
  on public.dnk_test_aai_links(user_id, created_at desc);
create index if not exists idx_dnk_test_aai_links_release
  on public.dnk_test_aai_links(release_id);

alter table public.dnk_test_defs enable row level security;
alter table public.dnk_test_sessions enable row level security;
alter table public.dnk_test_answers enable row level security;
alter table public.dnk_test_results enable row level security;
alter table public.dnk_test_aai_links enable row level security;

drop policy if exists dnk_test_defs_select_all on public.dnk_test_defs;
create policy dnk_test_defs_select_all on public.dnk_test_defs
  for select using (auth.role() = 'authenticated');

drop policy if exists dnk_test_sessions_select_own on public.dnk_test_sessions;
create policy dnk_test_sessions_select_own on public.dnk_test_sessions
  for select using (auth.uid() = user_id);
drop policy if exists dnk_test_sessions_insert_own on public.dnk_test_sessions;
create policy dnk_test_sessions_insert_own on public.dnk_test_sessions
  for insert with check (auth.uid() = user_id);
drop policy if exists dnk_test_sessions_update_own on public.dnk_test_sessions;
create policy dnk_test_sessions_update_own on public.dnk_test_sessions
  for update using (auth.uid() = user_id);

drop policy if exists dnk_test_answers_select_own on public.dnk_test_answers;
create policy dnk_test_answers_select_own on public.dnk_test_answers
  for select using (
    exists (
      select 1
      from public.dnk_test_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );
drop policy if exists dnk_test_answers_insert_own on public.dnk_test_answers;
create policy dnk_test_answers_insert_own on public.dnk_test_answers
  for insert with check (
    exists (
      select 1
      from public.dnk_test_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );
drop policy if exists dnk_test_answers_update_own on public.dnk_test_answers;
create policy dnk_test_answers_update_own on public.dnk_test_answers
  for update using (
    exists (
      select 1
      from public.dnk_test_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

drop policy if exists dnk_test_results_select_own on public.dnk_test_results;
create policy dnk_test_results_select_own on public.dnk_test_results
  for select using (
    exists (
      select 1
      from public.dnk_test_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

drop policy if exists dnk_test_aai_links_select_own on public.dnk_test_aai_links;
create policy dnk_test_aai_links_select_own on public.dnk_test_aai_links
  for select using (auth.uid() = user_id);
drop policy if exists dnk_test_aai_links_insert_own on public.dnk_test_aai_links;
create policy dnk_test_aai_links_insert_own on public.dnk_test_aai_links
  for insert with check (auth.uid() = user_id);
drop policy if exists dnk_test_aai_links_update_own on public.dnk_test_aai_links;
create policy dnk_test_aai_links_update_own on public.dnk_test_aai_links
  for update using (auth.uid() = user_id);

insert into public.dnk_test_defs (slug, title_ru, description, sort_order, is_active)
values
  ('artist_archetype', 'Архетип артиста', 'Определяет тип творческой энергии и сценической роли.', 1, true),
  ('tone_communication', 'Тон коммуникации', 'Определяет стиль общения артиста в контенте и соцсетях.', 2, true),
  ('story_core', 'Сюжетное ядро', 'Находит главный внутренний конфликт и сюжетные линии.', 3, true),
  ('growth_profile', 'Профиль роста', 'Показывает главные каналы масштабирования и стратегию роста.', 4, true),
  ('discipline_index', 'Индекс дисциплины', 'Измеряет системность и устойчивость рабочих ритмов.', 5, true),
  ('career_risk', 'Риск-профиль карьеры', 'Показывает сценарии самосаботажа и выход из них.', 6, true)
on conflict (slug) do update
set
  title_ru = excluded.title_ru,
  description = excluded.description,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active;
