-- ============================================================
-- 031 · Aurix Progress — ensure checkins + daily_notes exist
-- ============================================================
-- Fix for cases where progress_habits exists but other tables were not applied.

BEGIN;

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

ALTER TABLE public.progress_checkins ENABLE ROW LEVEL SECURITY;

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

ALTER TABLE public.progress_daily_notes ENABLE ROW LEVEL SECURITY;

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

