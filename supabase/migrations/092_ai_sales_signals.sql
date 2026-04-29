-- ════════════════════════════════════════════════════════════════════════════
-- 092_ai_sales_signals.sql
-- AI sales signals: кэш-таблица для сигналов покупательской готовности.
--
-- Логика: AiSalesService периодически читает последние N сообщений из
-- ai_studio_messages, прогоняет через Claude/GPT с системным промптом
-- "оцени sales_signal", и сохраняет результат сюда. Action Center и
-- Leads UI читают из этой таблицы, а не повторяют дорогой AI-вызов.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.ai_sales_signals (
  id                bigserial PRIMARY KEY,
  user_id           int NOT NULL,
  insight           text,                          -- что увидел AI
  recommendation    text,                          -- что нужно сделать
  sales_signal      text NOT NULL DEFAULT 'low',   -- low | medium | high
  suggested_action  text,                          -- человеко-читаемое действие
  product_offer     text,                          -- analysis_pro | promotion | distribution
  source_messages   int NOT NULL DEFAULT 0,        -- сколько сообщений учтено
  created_at        timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT ai_sales_signal_check CHECK (sales_signal IN ('low', 'medium', 'high')),
  CONSTRAINT ai_sales_offer_check CHECK (
    product_offer IS NULL OR product_offer IN ('analysis_pro', 'promotion', 'distribution')
  )
);

-- Индекс под Action Center: топ свежих high-signal сигналов.
CREATE INDEX IF NOT EXISTS idx_ai_sales_signal_high
  ON public.ai_sales_signals(sales_signal, created_at DESC)
  WHERE sales_signal = 'high';

CREATE INDEX IF NOT EXISTS idx_ai_sales_user
  ON public.ai_sales_signals(user_id, created_at DESC);
