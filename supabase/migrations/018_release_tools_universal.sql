-- Universal table for all AI tool results
CREATE TABLE IF NOT EXISTS public.release_tools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  release_id uuid NOT NULL REFERENCES public.releases(id) ON DELETE CASCADE,
  tool_key text NOT NULL,  -- 'growth-plan','budget-plan','release-packaging','content-plan-14','playlist-pitch-pack'
  input jsonb NOT NULL DEFAULT '{}',
  output jsonb NOT NULL DEFAULT '{}',
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, release_id, tool_key)
);

ALTER TABLE public.release_tools ENABLE ROW LEVEL SECURITY;

-- Owner can do everything with their own rows
CREATE POLICY "owner_select_release_tools" ON public.release_tools
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "owner_insert_release_tools" ON public.release_tools
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "owner_update_release_tools" ON public.release_tools
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "owner_delete_release_tools" ON public.release_tools
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Admin can read all
CREATE POLICY "admin_select_release_tools" ON public.release_tools
  FOR SELECT TO authenticated
  USING ((SELECT role FROM public.profiles WHERE user_id = auth.uid()) = 'admin');

-- Service role (edge functions) can upsert
CREATE POLICY "service_all_release_tools" ON public.release_tools
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS release_tools_updated_at ON public.release_tools;
CREATE TRIGGER release_tools_updated_at
  BEFORE UPDATE ON public.release_tools
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
