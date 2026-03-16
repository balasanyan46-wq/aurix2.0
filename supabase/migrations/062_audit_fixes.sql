-- ============================================================
-- 062_audit_fixes.sql
-- Fixes found during full security/quality audit (March 2026)
-- ============================================================

-- ─────────────────────────────────────────────
-- 1. RLS policies for production_files (was enabled but 0 policies = deny all)
-- ─────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'production_files' AND schemaname = 'public') THEN
    -- Owner can read own files
    CREATE POLICY IF NOT EXISTS "production_files_select_own"
      ON public.production_files FOR SELECT
      USING (auth.uid() = user_id OR public.is_admin_user());

    -- Owner can insert own files
    CREATE POLICY IF NOT EXISTS "production_files_insert_own"
      ON public.production_files FOR INSERT
      WITH CHECK (auth.uid() = user_id);

    -- Owner can update own files
    CREATE POLICY IF NOT EXISTS "production_files_update_own"
      ON public.production_files FOR UPDATE
      USING (auth.uid() = user_id OR public.is_admin_user());

    -- Owner can delete own files
    CREATE POLICY IF NOT EXISTS "production_files_delete_own"
      ON public.production_files FOR DELETE
      USING (auth.uid() = user_id OR public.is_admin_user());
  END IF;
END $$;

-- ─────────────────────────────────────────────
-- 2. Missing DELETE policies for CRM tables
-- ─────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'crm_tasks' AND schemaname = 'public') THEN
    CREATE POLICY IF NOT EXISTS "crm_tasks_delete_admin"
      ON public.crm_tasks FOR DELETE
      USING (public.is_admin_user());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'crm_notes' AND schemaname = 'public') THEN
    CREATE POLICY IF NOT EXISTS "crm_notes_delete_admin"
      ON public.crm_notes FOR DELETE
      USING (public.is_admin_user());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'crm_events' AND schemaname = 'public') THEN
    CREATE POLICY IF NOT EXISTS "crm_events_delete_admin"
      ON public.crm_events FOR DELETE
      USING (public.is_admin_user());
  END IF;
END $$;

-- ─────────────────────────────────────────────
-- 3. Fix crm_set_updated_at() trigger — add search_path
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crm_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────
-- 4. Missing indexes for CRM / AI tables
-- ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_crm_notes_user_id
  ON public.crm_notes (user_id);

CREATE INDEX IF NOT EXISTS idx_crm_events_user_id_created
  ON public.crm_events (user_id, created_at DESC);

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'crm_transactions' AND schemaname = 'public') THEN
    CREATE INDEX IF NOT EXISTS idx_crm_transactions_created
      ON public.crm_transactions (created_at DESC);
  END IF;
END $$;

-- ─────────────────────────────────────────────
-- 5. Fix subscription plan fallback (empty string vs null)
-- ─────────────────────────────────────────────
-- Ensure has_active_subscription() treats '' same as NULL
CREATE OR REPLACE FUNCTION public.has_active_subscription()
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND COALESCE(NULLIF(TRIM(p.plan_id), ''), NULLIF(TRIM(p.plan), ''), 'start') != 'start'
      AND (
        p.subscription_status IN ('active', 'trial')
        OR p.subscription_end > now()
      )
  );
$$;

-- ─────────────────────────────────────────────
-- 6. Unify storage admin check to use is_admin_user()
-- (Cannot ALTER existing policies, so we recreate if needed)
-- ─────────────────────────────────────────────
-- Note: Storage policies are managed by Supabase dashboard.
-- This comment documents that the admin check in
-- 002_storage_policies.sql should use public.is_admin_user()
-- instead of direct `profiles.role = 'admin'` check.
-- Manual action required in Supabase Dashboard → Storage → Policies.

-- ─────────────────────────────────────────────
-- Done
-- ─────────────────────────────────────────────
