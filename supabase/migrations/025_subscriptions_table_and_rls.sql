-- Subscriptions: source of truth for plan/status (users can only read their own)
-- Creates table, RLS policies, backfill, and sync triggers.

BEGIN;

-- 1) Table
CREATE TABLE IF NOT EXISTS public.subscriptions (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan text NOT NULL DEFAULT 'start',
  status text NOT NULL DEFAULT 'inactive',
  billing_period text NOT NULL DEFAULT 'monthly',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT subscriptions_plan_check CHECK (plan IN ('start', 'breakthrough', 'empire')),
  CONSTRAINT subscriptions_status_check CHECK (status IN ('inactive', 'active', 'past_due', 'canceled')),
  CONSTRAINT subscriptions_billing_period_check CHECK (billing_period IN ('monthly', 'yearly'))
);

-- updated_at trigger
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'subscriptions_updated_at'
  ) THEN
    CREATE TRIGGER subscriptions_updated_at
      BEFORE UPDATE ON public.subscriptions
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END$$;

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- 2) Policies
DROP POLICY IF EXISTS "subscriptions_select_own" ON public.subscriptions;
CREATE POLICY "subscriptions_select_own" ON public.subscriptions
  FOR SELECT USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.user_id = auth.uid() AND p.role = 'admin'
    )
  );

-- No user update policies on purpose (deny by default).
DROP POLICY IF EXISTS "subscriptions_admin_insert" ON public.subscriptions;
CREATE POLICY "subscriptions_admin_insert" ON public.subscriptions
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  );

DROP POLICY IF EXISTS "subscriptions_admin_update" ON public.subscriptions;
CREATE POLICY "subscriptions_admin_update" ON public.subscriptions
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  );

-- 3) Backfill existing users (take current values from profiles)
INSERT INTO public.subscriptions (user_id, plan, status, billing_period)
SELECT
  p.user_id,
  COALESCE(p.plan, 'start') AS plan,
  'active'::text            AS status,
  COALESCE(p.billing_period, 'monthly') AS billing_period
FROM public.profiles p
ON CONFLICT (user_id) DO NOTHING;

-- 4) Ensure new profiles get a default subscription row (Security Definer)
CREATE OR REPLACE FUNCTION public.create_default_subscription_for_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.subscriptions (user_id, plan, status, billing_period)
  VALUES (
    NEW.user_id,
    COALESCE(NEW.plan, 'start'),
    'active',
    COALESCE(NEW.billing_period, 'monthly')
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_create_subscription ON public.profiles;
CREATE TRIGGER trg_profiles_create_subscription
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.create_default_subscription_for_profile();

-- 5) Keep profiles.plan/billing_period in sync (for backward compatibility in UI)
CREATE OR REPLACE FUNCTION public.sync_profile_from_subscription()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET
    plan = NEW.plan,
    billing_period = NEW.billing_period,
    updated_at = now()
  WHERE user_id = NEW.user_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_subscriptions_sync_profile ON public.subscriptions;
CREATE TRIGGER trg_subscriptions_sync_profile
  AFTER INSERT OR UPDATE OF plan, billing_period ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_from_subscription();

COMMIT;

