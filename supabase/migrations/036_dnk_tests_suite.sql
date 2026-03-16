-- ============================================================
-- 036 · Aurix DNK Tests Suite (6 standalone tests)
-- ============================================================

-- Catalog of available tests
create table if not exists public.dnk_test_defs (
  slug         text primary key,
  title_ru     text not null,
  description  text not null default '',
  example_json jsonb not null default '{}'::jsonb,
  sort_order   int not null default 0,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

-- Sessions per user and test
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

-- Answers per session
create table if not exists public.dnk_test_answers (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null references public.dnk_test_sessions(id) on delete cascade,
  question_id  text not null,
  answer_type  text not null check (answer_type in ('scale', 'choice', 'sjt', 'open_text')),
  answer_json  jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  unique (session_id, question_id)
);

-- Result per generation for a test session
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

-- Optional link layer for AAI correlation hints
create table if not exists public.dnk_test_aai_links (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references auth.users(id) on delete cascade,
  release_id            uuid references public.releases(id) on delete cascade,
  test_slug             text not null references public.dnk_test_defs(slug) on delete cascade,
  result_id             uuid references public.dnk_test_results(id) on delete cascade,
  expected_growth_channel text not null default '',
  notes                 text not null default '',
  created_at            timestamptz not null default now()
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

alter table public.dnk_test_sessions enable row level security;
alter table public.dnk_test_answers enable row level security;
alter table public.dnk_test_results enable row level security;
alter table public.dnk_test_aai_links enable row level security;

-- Sessions
drop policy if exists dnk_test_sessions_select_own on public.dnk_test_sessions;
create policy dnk_test_sessions_select_own on public.dnk_test_sessions
  for select using (auth.uid() = user_id);
drop policy if exists dnk_test_sessions_insert_own on public.dnk_test_sessions;
create policy dnk_test_sessions_insert_own on public.dnk_test_sessions
  for insert with check (auth.uid() = user_id);
drop policy if exists dnk_test_sessions_update_own on public.dnk_test_sessions;
create policy dnk_test_sessions_update_own on public.dnk_test_sessions
  for update using (auth.uid() = user_id);

-- Answers
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

-- Results
drop policy if exists dnk_test_results_select_own on public.dnk_test_results;
create policy dnk_test_results_select_own on public.dnk_test_results
  for select using (
    exists (
      select 1
      from public.dnk_test_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

-- AAI links
drop policy if exists dnk_test_aai_links_select_own on public.dnk_test_aai_links;
create policy dnk_test_aai_links_select_own on public.dnk_test_aai_links
  for select using (auth.uid() = user_id);
drop policy if exists dnk_test_aai_links_insert_own on public.dnk_test_aai_links;
create policy dnk_test_aai_links_insert_own on public.dnk_test_aai_links
  for insert with check (auth.uid() = user_id);
drop policy if exists dnk_test_aai_links_update_own on public.dnk_test_aai_links;
create policy dnk_test_aai_links_update_own on public.dnk_test_aai_links
  for update using (auth.uid() = user_id);

-- Seed 6 tests
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
-- ============================================================
-- 036 · AURIX DNK Tests Suite (6 standalone tests)
-- ============================================================

-- Catalog of available DNK tests
CREATE TABLE IF NOT EXISTS public.dnk_test_defs (
  slug            text PRIMARY KEY,
  title_ru        text NOT NULL,
  description_ru  text NOT NULL,
  example_result  jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Test sessions: one run of one test
CREATE TABLE IF NOT EXISTS public.dnk_test_sessions (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  test_slug   text        NOT NULL REFERENCES public.dnk_test_defs(slug) ON DELETE RESTRICT,
  status      text        NOT NULL DEFAULT 'in_progress'
                        CHECK (status IN ('in_progress', 'finished', 'abandoned')),
  locale      text        NOT NULL DEFAULT 'ru',
  version     int         NOT NULL DEFAULT 1,
  started_at  timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Answers for test sessions
CREATE TABLE IF NOT EXISTS public.dnk_test_answers (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id   uuid        NOT NULL REFERENCES public.dnk_test_sessions(id) ON DELETE CASCADE,
  question_id  text        NOT NULL,
  answer_type  text        NOT NULL CHECK (answer_type IN ('scale', 'choice', 'sjt', 'open_text')),
  answer_json  jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, question_id)
);

-- Generated results per test session
CREATE TABLE IF NOT EXISTS public.dnk_test_results (
  id               uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id       uuid        NOT NULL REFERENCES public.dnk_test_sessions(id) ON DELETE CASCADE,
  test_slug        text        NOT NULL REFERENCES public.dnk_test_defs(slug) ON DELETE RESTRICT,
  score_axes       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  summary          text        NOT NULL DEFAULT '',
  strengths        jsonb       NOT NULL DEFAULT '[]'::jsonb,
  risks            jsonb       NOT NULL DEFAULT '[]'::jsonb,
  actions_7_days   jsonb       NOT NULL DEFAULT '[]'::jsonb,
  content_prompts  jsonb       NOT NULL DEFAULT '[]'::jsonb,
  payload          jsonb       NOT NULL DEFAULT '{}'::jsonb,
  regen_count      int         NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- Optional link layer to AAI recommendations
CREATE TABLE IF NOT EXISTS public.dnk_test_aai_links (
  id                      uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id                 uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  test_slug               text        NOT NULL REFERENCES public.dnk_test_defs(slug) ON DELETE CASCADE,
  source_result_id        uuid        REFERENCES public.dnk_test_results(id) ON DELETE SET NULL,
  expected_growth_channel text        NOT NULL,
  confidence              numeric(5,2) NOT NULL DEFAULT 0,
  hint                    text        NOT NULL DEFAULT '',
  created_at              timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dnk_test_sessions_user_slug_created
  ON public.dnk_test_sessions(user_id, test_slug, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dnk_test_answers_session
  ON public.dnk_test_answers(session_id);
CREATE INDEX IF NOT EXISTS idx_dnk_test_results_session
  ON public.dnk_test_results(session_id);
CREATE INDEX IF NOT EXISTS idx_dnk_test_results_slug_created
  ON public.dnk_test_results(test_slug, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dnk_test_aai_links_user_created
  ON public.dnk_test_aai_links(user_id, created_at DESC);

-- RLS
ALTER TABLE public.dnk_test_defs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnk_test_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnk_test_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnk_test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnk_test_aai_links ENABLE ROW LEVEL SECURITY;

-- dnk_test_defs: readable by authenticated users, write via service role/migrations
DROP POLICY IF EXISTS dnk_test_defs_select_all ON public.dnk_test_defs;
CREATE POLICY dnk_test_defs_select_all ON public.dnk_test_defs
  FOR SELECT USING (auth.role() = 'authenticated');

-- sessions
DROP POLICY IF EXISTS dnk_test_sessions_select_own ON public.dnk_test_sessions;
CREATE POLICY dnk_test_sessions_select_own ON public.dnk_test_sessions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS dnk_test_sessions_insert_own ON public.dnk_test_sessions;
CREATE POLICY dnk_test_sessions_insert_own ON public.dnk_test_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS dnk_test_sessions_update_own ON public.dnk_test_sessions;
CREATE POLICY dnk_test_sessions_update_own ON public.dnk_test_sessions
  FOR UPDATE USING (auth.uid() = user_id);

-- answers
DROP POLICY IF EXISTS dnk_test_answers_select_own ON public.dnk_test_answers;
CREATE POLICY dnk_test_answers_select_own ON public.dnk_test_answers
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM public.dnk_test_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS dnk_test_answers_insert_own ON public.dnk_test_answers;
CREATE POLICY dnk_test_answers_insert_own ON public.dnk_test_answers
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.dnk_test_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS dnk_test_answers_update_own ON public.dnk_test_answers;
CREATE POLICY dnk_test_answers_update_own ON public.dnk_test_answers
  FOR UPDATE USING (
    EXISTS (
      SELECT 1
      FROM public.dnk_test_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
  );

-- results
DROP POLICY IF EXISTS dnk_test_results_select_own ON public.dnk_test_results;
CREATE POLICY dnk_test_results_select_own ON public.dnk_test_results
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM public.dnk_test_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
  );

-- aai links
DROP POLICY IF EXISTS dnk_test_aai_links_select_own ON public.dnk_test_aai_links;
CREATE POLICY dnk_test_aai_links_select_own ON public.dnk_test_aai_links
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS dnk_test_aai_links_insert_own ON public.dnk_test_aai_links;
CREATE POLICY dnk_test_aai_links_insert_own ON public.dnk_test_aai_links
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS dnk_test_aai_links_update_own ON public.dnk_test_aai_links;
CREATE POLICY dnk_test_aai_links_update_own ON public.dnk_test_aai_links
  FOR UPDATE USING (auth.uid() = user_id);

-- Seed definitions
INSERT INTO public.dnk_test_defs (slug, title_ru, description_ru, example_result, is_active)
VALUES
  (
    'artist_archetype',
    'Архетип артиста',
    'Определяет тип творческой энергии и сценической роли.',
    '{"summary":"Твой ведущий архетип — Провокатор.","strengths":["Сильный сценический нерв"],"risks":["Резкие перепады тона"],"actions_7_days":["Собрать визуальный мудборд"],"content_prompts":["Сцена в стиле внутреннего конфликта"]}'::jsonb,
    true
  ),
  (
    'tone_communication',
    'Тон коммуникации',
    'Определяет стиль общения в соцсетях и формулировки бренда.',
    '{"summary":"Твоя речь — резкая и точная.","strengths":["Ясные формулировки"],"risks":["Перегиб в жесткости"],"actions_7_days":["Собрать словарь опор"],"content_prompts":["10 коротких фраз для сторис"]}'::jsonb,
    true
  ),
  (
    'story_core',
    'Сюжетное ядро',
    'Определяет главный внутренний конфликт и сюжетные линии песен.',
    '{"summary":"Ядро — конфликт свободы и контроля.","strengths":["Глубокая тема"],"risks":["Повторяемость образов"],"actions_7_days":["Наметить 5 линий сюжета"],"content_prompts":["Куплет по линии \"цена выбора\""]}'::jsonb,
    true
  ),
  (
    'growth_profile',
    'Профиль роста',
    'Определяет главный канал масштабирования и план на 30 дней.',
    '{"summary":"Основной канал — комьюнити.","strengths":["Сильный контакт с аудиторией"],"risks":["Распыление на все каналы"],"actions_7_days":["Запустить 3 комьюнити-активации"],"content_prompts":["Сценарий вовлекающего live"]}'::jsonb,
    true
  ),
  (
    'discipline_index',
    'Индекс дисциплины',
    'Определяет системность работы и регламент без срывов.',
    '{"summary":"Дисциплина средняя, блок — хаотичный старт дня.","strengths":["Умение работать рывками"],"risks":["Срывы при внешнем шуме"],"actions_7_days":["Ввести фикс-слот на студию"],"content_prompts":["Ритуал старта сессии"]}'::jsonb,
    true
  ),
  (
    'career_risk',
    'Риск-профиль карьеры',
    'Определяет самосаботаж и сценарии выхода.',
    '{"summary":"Стоп-фактор — затяжной перфекционизм.","strengths":["Высокая планка качества"],"risks":["Заморозка релизов"],"actions_7_days":["Правило 80% готовности"],"content_prompts":["Пост про завершение вместо допиливания"]}'::jsonb,
    true
  )
ON CONFLICT (slug) DO UPDATE
SET
  title_ru = EXCLUDED.title_ru,
  description_ru = EXCLUDED.description_ru,
  example_result = EXCLUDED.example_result,
  is_active = EXCLUDED.is_active;
