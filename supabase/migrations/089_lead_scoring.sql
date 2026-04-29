-- ════════════════════════════════════════════════════════════════════════════
-- 089_lead_scoring.sql
-- Lead scoring 0-100 + bucketизация cold/warm/hot.
--
-- Зачем: до этого не было ни единого числа, по которому можно было бы
-- оценить готовность артиста купить. Признаки покупательской активности
-- разбросаны по user_events. Эта миграция вводит persisted score, который
-- LeadScoringService обновляет периодически.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS lead_score smallint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS lead_bucket text NOT NULL DEFAULT 'cold',
  ADD COLUMN IF NOT EXISTS score_updated_at timestamptz;

-- Bucket constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_lead_bucket_check' AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_lead_bucket_check
      CHECK (lead_bucket IN ('cold', 'warm', 'hot'));
  END IF;
EXCEPTION WHEN undefined_table THEN NULL; END$$;

-- Score range constraint (защита от мусорных значений)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_lead_score_range' AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_lead_score_range
      CHECK (lead_score BETWEEN 0 AND 100);
  END IF;
EXCEPTION WHEN undefined_table THEN NULL; END$$;

-- Индексы под выборки hot/warm/cold с сортировкой по score.
CREATE INDEX IF NOT EXISTS idx_profiles_lead_bucket
  ON public.profiles(lead_bucket, lead_score DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_score_updated_at
  ON public.profiles(score_updated_at DESC NULLS LAST);

-- Лог пересчётов — пишем только если изменение существенное (>= 5 пунктов
-- или изменение bucket'а). Таблица позволяет смотреть динамику score'а.
CREATE TABLE IF NOT EXISTS public.lead_score_history (
  id          bigserial PRIMARY KEY,
  user_id     int NOT NULL,
  old_score   smallint,
  new_score   smallint NOT NULL,
  old_bucket  text,
  new_bucket  text NOT NULL,
  delta       smallint NOT NULL,  -- new_score - old_score
  reason      text,                -- например, 'recalc_cron' или 'manual'
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lead_score_history_user
  ON public.lead_score_history(user_id, created_at DESC);
