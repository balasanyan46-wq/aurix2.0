-- ============================================================
-- 027 · Aurix DNK — Artist DNA profiling tables
-- ============================================================

-- Sessions
CREATE TABLE IF NOT EXISTS public.dnk_sessions (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status      text        NOT NULL DEFAULT 'in_progress'
                          CHECK (status IN ('in_progress','finished','abandoned')),
  started_at  timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  locale      text        NOT NULL DEFAULT 'ru',
  version     int         NOT NULL DEFAULT 1,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Answers
CREATE TABLE IF NOT EXISTS public.dnk_answers (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id   uuid        NOT NULL REFERENCES public.dnk_sessions(id) ON DELETE CASCADE,
  question_id  text        NOT NULL,
  answer_type  text        NOT NULL CHECK (answer_type IN ('scale','choice','sjt','open_text')),
  answer_json  jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(session_id, question_id)
);

-- Results (one row per generation; re-generate = new row)
CREATE TABLE IF NOT EXISTS public.dnk_results (
  id              uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id      uuid        NOT NULL REFERENCES public.dnk_sessions(id) ON DELETE CASCADE,
  axes            jsonb       NOT NULL DEFAULT '{}'::jsonb,
  confidence      jsonb       NOT NULL DEFAULT '{}'::jsonb,
  profile_text    text,
  recommendations jsonb       NOT NULL DEFAULT '{}'::jsonb,
  prompts         jsonb       NOT NULL DEFAULT '{}'::jsonb,
  raw_features    jsonb       NOT NULL DEFAULT '{}'::jsonb,
  regen_count     int         NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dnk_sessions_user    ON public.dnk_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_dnk_answers_session   ON public.dnk_answers(session_id);
CREATE INDEX IF NOT EXISTS idx_dnk_results_session   ON public.dnk_results(session_id);

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE public.dnk_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnk_answers  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dnk_results  ENABLE ROW LEVEL SECURITY;

-- Sessions: owner can SELECT / INSERT / UPDATE
CREATE POLICY dnk_sessions_select_own ON public.dnk_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY dnk_sessions_insert_own ON public.dnk_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY dnk_sessions_update_own ON public.dnk_sessions
  FOR UPDATE USING (auth.uid() = user_id);

-- Answers: owner can SELECT / INSERT / UPDATE (via session FK)
CREATE POLICY dnk_answers_select_own ON public.dnk_answers
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.dnk_sessions s
            WHERE s.id = session_id AND s.user_id = auth.uid())
  );

CREATE POLICY dnk_answers_insert_own ON public.dnk_answers
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.dnk_sessions s
            WHERE s.id = session_id AND s.user_id = auth.uid())
  );

CREATE POLICY dnk_answers_update_own ON public.dnk_answers
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.dnk_sessions s
            WHERE s.id = session_id AND s.user_id = auth.uid())
  );

-- Results: owner can SELECT; INSERT is done by service_role (bypasses RLS)
CREATE POLICY dnk_results_select_own ON public.dnk_results
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.dnk_sessions s
            WHERE s.id = session_id AND s.user_id = auth.uid())
  );
