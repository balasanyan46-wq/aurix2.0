-- ============================================================
-- 063_auto_profile_and_fixes.sql
-- Auto-create profile on auth signup + schema fixes
-- Fully defensive: adds missing columns before using them
-- ============================================================

-- ─────────────────────────────────────────────
-- 0. Ensure all required columns exist
--    (some migrations may not have been applied)
-- ─────────────────────────────────────────────
DO $$
BEGIN
  -- user_id (from 040)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN user_id uuid;
  END IF;

  -- role (from 001)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN role text NOT NULL DEFAULT 'artist';
  END IF;

  -- account_status (from 001)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'account_status'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN account_status text NOT NULL DEFAULT 'active';
  END IF;

  -- plan (from 014)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'plan'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN plan text NOT NULL DEFAULT 'start';
  END IF;

  -- plan_id (from 051)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'plan_id'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN plan_id text NOT NULL DEFAULT 'start';
  END IF;

  -- subscription_status (from 051)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'subscription_status'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN subscription_status text NOT NULL DEFAULT 'trial';
  END IF;

  -- subscription_end (from 051)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'subscription_end'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN subscription_end timestamptz;
  END IF;

  -- display_name (from 001 or 008)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'display_name'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN display_name text;
  END IF;

  -- artist_name (from 001)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'artist_name'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN artist_name text;
  END IF;

  -- name (from 008)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'name'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN name text;
  END IF;

  -- phone (from 001)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'phone'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN phone text;
  END IF;

  -- city (from 008)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'city'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN city text;
  END IF;

  -- gender (from 008)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'gender'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN gender text;
  END IF;

  -- bio (from 008)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'bio'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN bio text;
  END IF;

  -- avatar_url (from 008)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'avatar_url'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN avatar_url text;
  END IF;

  -- billing_period (from 024)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'billing_period'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN billing_period text NOT NULL DEFAULT 'monthly';
  END IF;

  -- Ensure user_id has a unique index (needed for ON CONFLICT)
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'profiles' AND indexname = 'profiles_user_id_key'
  ) THEN
    BEGIN
      ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);
    EXCEPTION WHEN duplicate_table THEN
      NULL; -- constraint already exists under different name
    END;
  END IF;
END
$$;

-- ─────────────────────────────────────────────
-- 1. Auto-create profile when user signs up
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
  v_phone text;
  v_email text;
BEGIN
  v_email := COALESCE(NEW.email, '');
  v_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'display_name',
    NEW.raw_user_meta_data->>'artist_name',
    NULL
  );
  v_phone := NEW.raw_user_meta_data->>'phone';

  INSERT INTO public.profiles (
    user_id,
    email,
    display_name,
    artist_name,
    name,
    phone,
    role,
    account_status,
    plan,
    plan_id,
    subscription_status,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    v_email,
    v_name,
    v_name,
    v_name,
    v_phone,
    'artist',
    'active',
    'start',
    'start',
    'trial',
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Drop old trigger if exists, create new one
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────────
-- 2. Backfill: create profiles for any auth.users that don't have one
-- ─────────────────────────────────────────────
INSERT INTO public.profiles (user_id, email, role, account_status, plan, plan_id, subscription_status, created_at, updated_at)
SELECT
  u.id,
  COALESCE(u.email, ''),
  'artist',
  'active',
  'start',
  'start',
  'trial',
  COALESCE(u.created_at, NOW()),
  NOW()
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.profiles p WHERE p.user_id = u.id
)
ON CONFLICT (user_id) DO NOTHING;

-- ─────────────────────────────────────────────
-- 3. Fix RLS: update policies to use user_id
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (
    auth.uid() = user_id
    OR public.is_admin_user()
  );

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (
    auth.uid() = user_id
    OR public.is_admin_user()
  );

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
  );

-- ─────────────────────────────────────────────
-- Done
-- ─────────────────────────────────────────────
