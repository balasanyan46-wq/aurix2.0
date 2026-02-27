-- ============================================================
-- 030 · Aurix Progress — habits + daily check-ins + notes
-- ============================================================

BEGIN;

-- A) Habits
CREATE TABLE IF NOT EXISTS public.progress_habits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  category text NOT NULL DEFAULT 'content' CHECK (category IN ('content','music','admin','growth','health')),
  target_type text NOT NULL DEFAULT 'daily' CHECK (target_type IN ('daily','weekly')),
  target_count int NOT NULL DEFAULT 1 CHECK (target_count >= 0),
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_progress_habits_user_sort
  ON public.progress_habits(user_id, sort_order, created_at);

-- B) Check-ins (one cell per habit/day, upsertable)
CREATE TABLE IF NOT EXISTS public.progress_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  habit_id uuid NOT NULL REFERENCES public.progress_habits(id) ON DELETE CASCADE,
  day date NOT NULL,
  done_count int NOT NULL DEFAULT 1 CHECK (done_count >= 0),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, habit_id, day)
);

CREATE INDEX IF NOT EXISTS idx_progress_checkins_user_day
  ON public.progress_checkins(user_id, day);

CREATE INDEX IF NOT EXISTS idx_progress_checkins_habit_day
  ON public.progress_checkins(habit_id, day);

-- C) Daily notes (optional)
CREATE TABLE IF NOT EXISTS public.progress_daily_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day date NOT NULL,
  mood int CHECK (mood >= 1 AND mood <= 5),
  blocker text,
  win text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, day)
);

CREATE INDEX IF NOT EXISTS idx_progress_daily_notes_user_day
  ON public.progress_daily_notes(user_id, day);

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE public.progress_habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress_daily_notes ENABLE ROW LEVEL SECURITY;

-- progress_habits policies
DROP POLICY IF EXISTS progress_habits_select_own ON public.progress_habits;
CREATE POLICY progress_habits_select_own ON public.progress_habits
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_habits_insert_own ON public.progress_habits;
CREATE POLICY progress_habits_insert_own ON public.progress_habits
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_habits_update_own ON public.progress_habits;
CREATE POLICY progress_habits_update_own ON public.progress_habits
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_habits_delete_own ON public.progress_habits;
CREATE POLICY progress_habits_delete_own ON public.progress_habits
  FOR DELETE USING (auth.uid() = user_id);

-- progress_checkins policies
DROP POLICY IF EXISTS progress_checkins_select_own ON public.progress_checkins;
CREATE POLICY progress_checkins_select_own ON public.progress_checkins
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_checkins_insert_own ON public.progress_checkins;
CREATE POLICY progress_checkins_insert_own ON public.progress_checkins
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_checkins_update_own ON public.progress_checkins;
CREATE POLICY progress_checkins_update_own ON public.progress_checkins
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_checkins_delete_own ON public.progress_checkins;
CREATE POLICY progress_checkins_delete_own ON public.progress_checkins
  FOR DELETE USING (auth.uid() = user_id);

-- progress_daily_notes policies
DROP POLICY IF EXISTS progress_daily_notes_select_own ON public.progress_daily_notes;
CREATE POLICY progress_daily_notes_select_own ON public.progress_daily_notes
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_daily_notes_insert_own ON public.progress_daily_notes;
CREATE POLICY progress_daily_notes_insert_own ON public.progress_daily_notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_daily_notes_update_own ON public.progress_daily_notes;
CREATE POLICY progress_daily_notes_update_own ON public.progress_daily_notes
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS progress_daily_notes_delete_own ON public.progress_daily_notes;
CREATE POLICY progress_daily_notes_delete_own ON public.progress_daily_notes
  FOR DELETE USING (auth.uid() = user_id);

COMMIT;

