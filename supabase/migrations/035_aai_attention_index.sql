-- ============================================================
-- 035 · AURIX Attention Index (AAI)
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.release_page_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  release_id uuid NOT NULL REFERENCES public.releases(id) ON DELETE CASCADE,
  session_id text NOT NULL,
  country text,
  referrer text,
  user_agent text,
  ip_hash text,
  event_type text NOT NULL DEFAULT 'view' CHECK (event_type IN ('view', 'leave')),
  engaged_seconds int NOT NULL DEFAULT 0,
  is_suspicious boolean NOT NULL DEFAULT false,
  is_filtered boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.release_clicks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  release_id uuid NOT NULL REFERENCES public.releases(id) ON DELETE CASCADE,
  platform text NOT NULL,
  redirect_url text,
  session_id text NOT NULL,
  country text,
  referrer text,
  user_agent text,
  ip_hash text,
  is_suspicious boolean NOT NULL DEFAULT false,
  is_filtered boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.release_attention_index (
  release_id uuid PRIMARY KEY REFERENCES public.releases(id) ON DELETE CASCADE,
  impulse_score numeric(5,2) NOT NULL DEFAULT 0,
  conversion_score numeric(5,2) NOT NULL DEFAULT 0,
  engagement_score numeric(5,2) NOT NULL DEFAULT 0,
  geography_score numeric(5,2) NOT NULL DEFAULT 0,
  total_score numeric(5,2) NOT NULL DEFAULT 0,
  status_code text NOT NULL DEFAULT 'quiet' CHECK (status_code IN ('hot', 'accelerating', 'watching', 'quiet')),
  score_prev numeric(5,2) NOT NULL DEFAULT 0,
  delta_24h numeric(6,2) NOT NULL DEFAULT 0,
  delta_48h numeric(6,2) NOT NULL DEFAULT 0,
  views_48h int NOT NULL DEFAULT 0,
  clicks_48h int NOT NULL DEFAULT 0,
  unique_countries_48h int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_release_page_views_release_created
  ON public.release_page_views(release_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_release_page_views_session_release_created
  ON public.release_page_views(session_id, release_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_release_clicks_release_created
  ON public.release_clicks(release_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_release_clicks_release_platform_created
  ON public.release_clicks(release_id, platform, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_release_clicks_session_release_created
  ON public.release_clicks(session_id, release_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_release_attention_index_total
  ON public.release_attention_index(total_score DESC, updated_at DESC);

ALTER TABLE public.release_page_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.release_clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.release_attention_index ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "aai_views_admin_select" ON public.release_page_views;
CREATE POLICY "aai_views_admin_select" ON public.release_page_views
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.user_id = auth.uid() AND p.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "aai_clicks_admin_select" ON public.release_clicks;
CREATE POLICY "aai_clicks_admin_select" ON public.release_clicks
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.user_id = auth.uid() AND p.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "aai_index_owner_admin_select" ON public.release_attention_index;
CREATE POLICY "aai_index_owner_admin_select" ON public.release_attention_index
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.releases r
      WHERE r.id = release_attention_index.release_id AND r.owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.user_id = auth.uid() AND p.role = 'admin'
    )
  );

COMMIT;

