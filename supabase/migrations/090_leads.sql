-- ════════════════════════════════════════════════════════════════════════════
-- 090_leads.sql
-- Автоматический leads pipeline (отличается от crm_leads из 048).
--
-- crm_leads (048) — ручная sales-pipeline (deals, promo). Этапы:
--   new, in_work, need_info, offer_sent, paid, production, done, archived.
--
-- leads (этот файл) — автоматический pipeline lead scoring → conversion.
--   Источник: lead_score >= 70 (hot) → запись создаётся LeadService'ом.
--   Жизненный цикл: new → contacted → in_progress → converted (на платёж) | lost (14 дней неактивности).
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.leads (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         int NOT NULL,
  lead_score      smallint NOT NULL DEFAULT 0,
  lead_bucket     text NOT NULL DEFAULT 'cold',
  status          text NOT NULL DEFAULT 'new',
  assigned_to     int NULL,                          -- admin user_id
  last_contact_at timestamptz NULL,
  next_action     text NULL,
  source          text NOT NULL DEFAULT 'system',    -- ai, system, manual
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT leads_status_check CHECK (
    status IN ('new', 'contacted', 'in_progress', 'converted', 'lost')
  ),
  CONSTRAINT leads_bucket_check CHECK (
    lead_bucket IN ('cold', 'warm', 'hot')
  ),
  CONSTRAINT leads_source_check CHECK (
    source IN ('ai', 'system', 'manual')
  ),
  CONSTRAINT leads_score_range CHECK (
    lead_score BETWEEN 0 AND 100
  )
);

-- Индексы под фильтры из ТЗ.
CREATE INDEX IF NOT EXISTS idx_leads_user ON public.leads(user_id);
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_bucket ON public.leads(lead_bucket, lead_score DESC);
CREATE INDEX IF NOT EXISTS idx_leads_assigned ON public.leads(assigned_to, status)
  WHERE assigned_to IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_leads_updated ON public.leads(updated_at DESC);

-- Уникальность: один активный lead на пользователя. converted/lost — архивные.
-- Это позволяет переоткрывать lead если юзер вернулся (создаём новый после lost).
CREATE UNIQUE INDEX IF NOT EXISTS uniq_leads_user_active
  ON public.leads(user_id)
  WHERE status NOT IN ('converted', 'lost');

-- updated_at триггер
CREATE OR REPLACE FUNCTION public.set_leads_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_leads_updated_at ON public.leads;
CREATE TRIGGER trg_leads_updated_at
  BEFORE UPDATE ON public.leads
  FOR EACH ROW EXECUTE FUNCTION public.set_leads_updated_at();
