-- ════════════════════════════════════════════════════════════════════════════
-- 094_offer_funnel.sql
-- Offer → Payment funnel: воронка отправленных офферов до оплаты.
--
-- События в user_events (уже пишутся через POST /admin/notifications):
--   - offer_sent    — менеджер отправил оффер (meta.product_offer)
--   - offer_clicked — юзер открыл оффер (Flutter→backend whitelist)
--   - checkout_started — нажал "Оплатить" на странице плана
--   - payment_success — успешная оплата
--
-- Воронка: offer_sent → offer_clicked → checkout_started → payment_success.
-- Окно атрибуции: 14 дней с момента offer_sent (после — считаем organic).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.v_offer_funnel AS
WITH offers AS (
  -- Все отправленные офферы за последние 60 дней.
  SELECT
    ue.id,
    ue.user_id,
    ue.created_at AS sent_at,
    COALESCE(ue.meta->>'product_offer', 'unknown') AS product_offer
  FROM user_events ue
  WHERE ue.event = 'offer_sent'
    AND ue.created_at >= now() - interval '60 days'
),
attribution AS (
  -- Для каждого оффера ищем первое follow-up событие в окне 14 дней.
  SELECT
    o.id AS offer_id,
    o.user_id,
    o.product_offer,
    o.sent_at,
    EXISTS (
      SELECT 1 FROM user_events ue2
       WHERE ue2.user_id = o.user_id
         AND ue2.event = 'offer_clicked'
         AND ue2.created_at BETWEEN o.sent_at AND o.sent_at + interval '14 days'
    ) AS clicked,
    EXISTS (
      SELECT 1 FROM user_events ue3
       WHERE ue3.user_id = o.user_id
         AND ue3.event = 'checkout_started'
         AND ue3.created_at BETWEEN o.sent_at AND o.sent_at + interval '14 days'
    ) AS checkout,
    EXISTS (
      SELECT 1 FROM user_events ue4
       WHERE ue4.user_id = o.user_id
         AND ue4.event = 'payment_success'
         AND ue4.created_at BETWEEN o.sent_at AND o.sent_at + interval '14 days'
    ) AS paid,
    -- Сумма confirmed payments в окне атрибуции (для revenue per offer).
    COALESCE((
      SELECT SUM(p.amount)
        FROM payments p
       WHERE p.user_id = o.user_id
         AND p.status = 'confirmed'
         AND p.confirmed_at BETWEEN o.sent_at AND o.sent_at + interval '14 days'
    ), 0)::bigint AS revenue_kopecks
  FROM offers o
)
SELECT * FROM attribution;

-- Aggregated stats per product_offer.
CREATE OR REPLACE VIEW public.v_offer_funnel_stats AS
SELECT
  product_offer,
  COUNT(*)::int                                    AS sent,
  COUNT(*) FILTER (WHERE clicked)::int             AS clicked,
  COUNT(*) FILTER (WHERE checkout)::int            AS checkout,
  COUNT(*) FILTER (WHERE paid)::int                AS paid,
  COALESCE(SUM(revenue_kopecks), 0)::bigint        AS revenue_kopecks,
  -- Конверсии в %, относительно sent (не cascade).
  CASE WHEN COUNT(*) > 0
       THEN ROUND(COUNT(*) FILTER (WHERE clicked)::numeric * 100 / COUNT(*), 2)
       ELSE 0 END                                  AS click_pct,
  CASE WHEN COUNT(*) > 0
       THEN ROUND(COUNT(*) FILTER (WHERE checkout)::numeric * 100 / COUNT(*), 2)
       ELSE 0 END                                  AS checkout_pct,
  CASE WHEN COUNT(*) > 0
       THEN ROUND(COUNT(*) FILTER (WHERE paid)::numeric * 100 / COUNT(*), 2)
       ELSE 0 END                                  AS paid_pct
FROM v_offer_funnel
GROUP BY product_offer
ORDER BY sent DESC;
