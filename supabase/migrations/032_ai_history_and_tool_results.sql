-- ============================================================
-- 032 · Aurix AI history (Studio chat) + Tool results
-- ============================================================

BEGIN;

-- A) Studio AI chat messages (per user)
CREATE TABLE IF NOT EXISTS public.ai_studio_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('user','assistant','system')),
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_studio_messages_user_created
  ON public.ai_studio_messages(user_id, created_at DESC);

-- B) Tool runs / results (per user + tool + resource)
CREATE TABLE IF NOT EXISTS public.ai_tool_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tool_id text NOT NULL,
  resource_type text NOT NULL DEFAULT 'release' CHECK (resource_type IN ('release','track','other')),
  resource_id uuid,
  input jsonb,
  quick_prompt text,
  result_markdown text,
  error_text text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_tool_results_user_tool_resource_created
  ON public.ai_tool_results(user_id, tool_id, resource_id, created_at DESC);

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE public.ai_studio_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_tool_results ENABLE ROW LEVEL SECURITY;

-- ai_studio_messages policies
DROP POLICY IF EXISTS ai_studio_messages_select_own ON public.ai_studio_messages;
CREATE POLICY ai_studio_messages_select_own ON public.ai_studio_messages
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_studio_messages_insert_own ON public.ai_studio_messages;
CREATE POLICY ai_studio_messages_insert_own ON public.ai_studio_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_studio_messages_update_own ON public.ai_studio_messages;
CREATE POLICY ai_studio_messages_update_own ON public.ai_studio_messages
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_studio_messages_delete_own ON public.ai_studio_messages;
CREATE POLICY ai_studio_messages_delete_own ON public.ai_studio_messages
  FOR DELETE USING (auth.uid() = user_id);

-- ai_tool_results policies
DROP POLICY IF EXISTS ai_tool_results_select_own ON public.ai_tool_results;
CREATE POLICY ai_tool_results_select_own ON public.ai_tool_results
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_tool_results_insert_own ON public.ai_tool_results;
CREATE POLICY ai_tool_results_insert_own ON public.ai_tool_results
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_tool_results_update_own ON public.ai_tool_results;
CREATE POLICY ai_tool_results_update_own ON public.ai_tool_results
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_tool_results_delete_own ON public.ai_tool_results;
CREATE POLICY ai_tool_results_delete_own ON public.ai_tool_results
  FOR DELETE USING (auth.uid() = user_id);

COMMIT;

