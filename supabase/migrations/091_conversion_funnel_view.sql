-- ════════════════════════════════════════════════════════════════════════════
-- 091_conversion_funnel_view.sql
-- View `v_conversion_funnel` — артистическая воронка с деньгами.
--
-- Шаги:
--   1) register             — все юзеры
--   2) track_uploaded       — загрузил трек
--   3) ai_chat              — попробовал AI-анализ
--   4) release_created      — оформил релиз
--   5) payment              — оплатил
--   6) repeat               — вернулся после оплаты (>= 1 событие)
--
-- Считаем по уникальным user_id. Revenue — сумма confirmed payments в ₽.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.v_conversion_funnel AS
WITH base AS (
  SELECT u.id AS user_id, u.created_at AS registered_at
  FROM users u
),
events_agg AS (
  SELECT
    user_id,
    BOOL_OR(event = 'track_uploaded') AS has_track,
    BOOL_OR(event = 'ai_chat') AS has_ai,
    BOOL_OR(event IN ('release_created', 'release_submitted')) AS has_release,
    MAX(CASE WHEN event = 'subscription_changed' THEN created_at END) AS last_payment_event,
    MAX(created_at) AS last_event
  FROM user_events
  GROUP BY user_id
),
payments_agg AS (
  SELECT
    user_id,
    BOOL_OR(status = 'confirmed') AS has_payment,
    MIN(CASE WHEN status = 'confirmed' THEN confirmed_at END) AS first_payment_at,
    SUM(CASE WHEN status = 'confirmed' THEN amount ELSE 0 END) AS revenue_kopecks
  FROM payments
  GROUP BY user_id
)
SELECT
  COUNT(*)::int AS step1_register,
  COUNT(*) FILTER (WHERE COALESCE(e.has_track, false))::int AS step2_track_uploaded,
  COUNT(*) FILTER (WHERE COALESCE(e.has_ai, false))::int AS step3_ai_chat,
  COUNT(*) FILTER (WHERE COALESCE(e.has_release, false))::int AS step4_release_created,
  COUNT(*) FILTER (WHERE COALESCE(p.has_payment, false))::int AS step5_payment,
  -- repeat: после первого платежа были события
  COUNT(*) FILTER (
    WHERE p.has_payment
      AND e.last_event IS NOT NULL
      AND p.first_payment_at IS NOT NULL
      AND e.last_event > p.first_payment_at
  )::int AS step6_repeat,
  COALESCE(SUM(p.revenue_kopecks), 0)::bigint AS total_revenue_kopecks
FROM base b
LEFT JOIN events_agg e USING (user_id)
LEFT JOIN payments_agg p USING (user_id);

-- Per-step revenue: revenue, который сгенерировали юзеры, дошедшие до шага.
-- Это полезно для "сколько денег у нас уже сидит на каждом шаге воронки".
CREATE OR REPLACE VIEW public.v_conversion_revenue_by_step AS
WITH events_agg AS (
  SELECT
    user_id,
    BOOL_OR(event = 'track_uploaded') AS has_track,
    BOOL_OR(event = 'ai_chat') AS has_ai,
    BOOL_OR(event IN ('release_created', 'release_submitted')) AS has_release
  FROM user_events
  GROUP BY user_id
),
payments_agg AS (
  SELECT user_id, SUM(amount) AS revenue
  FROM payments WHERE status = 'confirmed'
  GROUP BY user_id
)
SELECT
  'register' AS step,
  COALESCE(SUM(p.revenue), 0)::bigint AS revenue_kopecks
FROM users u
LEFT JOIN payments_agg p ON p.user_id = u.id
UNION ALL
SELECT
  'track_uploaded' AS step,
  COALESCE(SUM(p.revenue), 0)::bigint
FROM events_agg e
LEFT JOIN payments_agg p ON p.user_id = e.user_id
WHERE e.has_track
UNION ALL
SELECT
  'ai_chat' AS step,
  COALESCE(SUM(p.revenue), 0)::bigint
FROM events_agg e
LEFT JOIN payments_agg p ON p.user_id = e.user_id
WHERE e.has_ai
UNION ALL
SELECT
  'release_created' AS step,
  COALESCE(SUM(p.revenue), 0)::bigint
FROM events_agg e
LEFT JOIN payments_agg p ON p.user_id = e.user_id
WHERE e.has_release;
