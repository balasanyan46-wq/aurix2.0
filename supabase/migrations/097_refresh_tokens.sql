-- ════════════════════════════════════════════════════════════════════════════
-- 097_refresh_tokens.sql
-- Восстановительная миграция: refresh_tokens используется auth.service.ts и
-- admin kill-sessions, но миграции для неё в репозитории не оказалось.
--
-- Если таблица УЖЕ существует в проде — миграция no-op (CREATE IF NOT EXISTS).
-- Если её НЕТ — создастся со схемой, которую ожидает код.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.refresh_tokens (
  id          bigserial PRIMARY KEY,
  user_id     int NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  -- Hash, не raw token (raw хранится только у клиента).
  token_hash  text NOT NULL UNIQUE,
  expires_at  timestamptz NOT NULL,
  user_agent  text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Индексы под основные сценарии:
--   - быстрый поиск по token_hash при validate (uuid-индекс через UNIQUE)
--   - kill-sessions: DELETE WHERE user_id = $1
--   - cleanup expired: WHERE expires_at < now()
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user
  ON public.refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires
  ON public.refresh_tokens(expires_at);
