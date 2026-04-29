-- ════════════════════════════════════════════════════════════════════════════
-- 098_push_tokens.sql
-- Хранилище FCM/APNS токенов для push-нотификаций.
--
-- Один user_id может иметь несколько токенов (мобильное приложение, веб-PWA,
-- разные устройства). Уникальность по token (один FCM-токен — одно устройство).
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.push_tokens (
  id          bigserial PRIMARY KEY,
  user_id     int NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  -- Платформа: fcm (Android/Web), apns (iOS). Расширяемо.
  platform    text NOT NULL CHECK (platform IN ('fcm', 'apns', 'web')),
  -- Сам token (FCM registration token или APNS device token).
  token       text NOT NULL,
  -- Доп. контекст для отладки.
  device_info jsonb DEFAULT '{}',
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  -- Когда токен использовался последний раз — для cleanup'а старых.
  last_used_at timestamptz,

  CONSTRAINT push_tokens_token_unique UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_user_active
  ON public.push_tokens(user_id, active)
  WHERE active = true;
