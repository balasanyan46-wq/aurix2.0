-- Migration: rename plan slugs from base/pro/studio → start/breakthrough/empire
-- Run in Supabase SQL Editor (Dashboard → SQL Editor → New query → paste → Run)
-- After running: Dashboard → Settings → API → click "Reload" to refresh PostgREST schema cache.

BEGIN;

-- 1. Ensure plan column exists
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS plan text NOT NULL DEFAULT 'start';

-- 2. Migrate legacy values
UPDATE public.profiles SET plan = 'start'        WHERE plan IN ('base', 'basic', 'BASE')  OR plan IS NULL;
UPDATE public.profiles SET plan = 'breakthrough'  WHERE plan IN ('pro', 'PRO');
UPDATE public.profiles SET plan = 'empire'        WHERE plan IN ('studio', 'STUDIO');

-- 3. Set new default
ALTER TABLE public.profiles ALTER COLUMN plan SET DEFAULT 'start';

-- 4. Add CHECK constraint (drop old one first if exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'profiles_plan_check' AND table_name = 'profiles'
  ) THEN
    ALTER TABLE public.profiles DROP CONSTRAINT profiles_plan_check;
  END IF;
END$$;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_plan_check
  CHECK (plan IN ('start', 'breakthrough', 'empire'));

COMMIT;
