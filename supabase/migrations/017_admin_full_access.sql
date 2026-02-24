-- Admin full access to releases, tracks, and storage
-- Run in Supabase SQL Editor

BEGIN;

-- Admin can read ALL releases (including drafts)
DROP POLICY IF EXISTS "admin_select_all_releases" ON public.releases;
CREATE POLICY "admin_select_all_releases" ON public.releases
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  );

-- Admin can update ALL releases
DROP POLICY IF EXISTS "admin_update_all_releases" ON public.releases;
CREATE POLICY "admin_update_all_releases" ON public.releases
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  );

-- Admin can read ALL tracks
DROP POLICY IF EXISTS "admin_select_all_tracks" ON public.tracks;
CREATE POLICY "admin_select_all_tracks" ON public.tracks
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  );

-- Admin can read ALL admin_notes
DROP POLICY IF EXISTS "admin_select_all_notes" ON public.admin_notes;
CREATE POLICY "admin_select_all_notes" ON public.admin_notes
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  );

-- Admin can insert admin_notes
DROP POLICY IF EXISTS "admin_insert_notes" ON public.admin_notes;
CREATE POLICY "admin_insert_notes" ON public.admin_notes
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.role = 'admin')
  );

-- Create admin_notes table if not exists
CREATE TABLE IF NOT EXISTS public.admin_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  release_id uuid NOT NULL REFERENCES public.releases(id) ON DELETE CASCADE,
  admin_id uuid NOT NULL REFERENCES auth.users(id),
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY;

COMMIT;
