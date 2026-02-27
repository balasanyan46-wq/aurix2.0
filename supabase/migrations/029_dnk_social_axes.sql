-- ============================================================
-- 029 · Aurix DNK v2 — Add social_axes column to dnk_results
-- ============================================================

ALTER TABLE public.dnk_results
  ADD COLUMN IF NOT EXISTS social_axes jsonb NOT NULL DEFAULT '{}'::jsonb;
