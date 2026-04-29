-- ════════════════════════════════════════════════════════════════════════════
-- 093_notifications_types_sales.sql
-- Расширяем CHECK constraint notifications.type для sales-pipeline.
--
-- Существующие (миграции 065 + 076):
--   system, promo, warning, success, ai, retention, announcement
--
-- Новые (для sales-pipeline и POST /admin/notifications):
--   sales        — обычное sales-сообщение от менеджера ("Написать")
--   offer        — персональное предложение ("Отправить оффер")
--   admin        — generic admin-message (используется adminSend endpoint'ом)
--   internal     — внутреннее in-app только, без email/push
--
-- НЕ добавляем 'push'/'email' — это не type сообщения, а transport.
-- Backend мапит body.type='push'|'email' → DB type='internal' (один и тот же
-- in-app row), а transport (email send) отрабатывает отдельно.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'system',
    'promo',
    'warning',
    'success',
    'ai',
    'retention',
    'announcement',
    'sales',
    'offer',
    'admin',
    'internal'
  ));
