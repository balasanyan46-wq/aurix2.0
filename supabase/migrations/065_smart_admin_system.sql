-- ============================================================
-- 065 · Smart Admin System
--   - auto_actions (trigger-based automation rules)
--   - notifications (user notifications)
--   - user_sessions + session_events (session tracking)
-- ============================================================

-- ─── 1. AUTO ACTIONS ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.auto_actions (
  id            serial       PRIMARY KEY,
  trigger_type  text         NOT NULL CHECK (trigger_type IN ('error','inactivity','drop_off','success','event')),
  event_type    text,                          -- e.g. 'login', 'release_created', 'ai_chat'
  condition     jsonb        NOT NULL DEFAULT '{}',  -- e.g. {"min_count": 3, "window_hours": 24}
  action_type   text         NOT NULL CHECK (action_type IN ('notify','bonus','create_ticket','assign_operator','email')),
  payload       jsonb        NOT NULL DEFAULT '{}',  -- e.g. {"title": "...", "message": "..."}
  is_active     boolean      NOT NULL DEFAULT true,
  name          text,                          -- human-readable label
  description   text,
  executions    int          NOT NULL DEFAULT 0,
  last_fired_at timestamptz,
  created_at    timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auto_actions_active ON public.auto_actions(is_active, trigger_type);

-- ─── 2. AUTO ACTION LOG (what fired, when, for whom) ────────

CREATE TABLE IF NOT EXISTS public.auto_action_log (
  id             bigserial    PRIMARY KEY,
  action_id      int          NOT NULL REFERENCES public.auto_actions(id) ON DELETE CASCADE,
  user_id        int          NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  trigger_event  text,
  result         text,        -- 'ok' | 'error' | 'skipped'
  details        jsonb        DEFAULT '{}',
  created_at     timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auto_action_log_action ON public.auto_action_log(action_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_auto_action_log_user   ON public.auto_action_log(user_id, created_at DESC);

-- ─── 3. NOTIFICATIONS ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notifications (
  id         bigserial    PRIMARY KEY,
  user_id    int          NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title      text         NOT NULL,
  message    text         NOT NULL,
  type       text         NOT NULL DEFAULT 'system' CHECK (type IN ('system','promo','warning','success','ai')),
  is_read    boolean      NOT NULL DEFAULT false,
  meta       jsonb        DEFAULT '{}',
  created_at timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user    ON public.notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON public.notifications(created_at DESC);

-- ─── 4. USER SESSIONS ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_sessions (
  id         bigserial    PRIMARY KEY,
  user_id    int          NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  started_at timestamptz  NOT NULL DEFAULT now(),
  ended_at   timestamptz,
  duration_s int,           -- computed on close
  device     text,          -- 'web' | 'ios' | 'android'
  ip         text,
  user_agent text
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON public.user_sessions(user_id, started_at DESC);

-- ─── 5. SESSION EVENTS ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.session_events (
  id          bigserial    PRIMARY KEY,
  session_id  bigint       NOT NULL REFERENCES public.user_sessions(id) ON DELETE CASCADE,
  event_type  text         NOT NULL,   -- 'screen_view', 'action', 'error', 'api_call'
  screen      text,                    -- '/home', '/releases', '/studio'
  action      text,                    -- 'tap_create', 'submit_release', 'ai_generate'
  meta        jsonb        DEFAULT '{}',
  created_at  timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_session_events_session ON public.session_events(session_id, created_at);

-- ─── 6. SEED DEFAULT AUTO ACTIONS ──────────────────────────

INSERT INTO public.auto_actions (trigger_type, event_type, condition, action_type, payload, name, description) VALUES
  ('inactivity', NULL, '{"inactive_hours": 24}', 'notify',
   '{"title": "Мы скучаем!", "message": "Ты не заходил 24 часа. Твоя музыка ждёт!", "type": "promo"}',
   'Неактивность 24ч', 'Уведомление при отсутствии активности 24 часа'),

  ('error', NULL, '{"min_errors": 3, "window_hours": 1}', 'create_ticket',
   '{"subject": "Автотикет: повторяющиеся ошибки", "priority": "high"}',
   'Ошибки × 3', 'Авто-создание тикета при 3+ ошибках за час'),

  ('success', 'release_submitted', '{}', 'notify',
   '{"title": "Релиз отправлен! 🎉", "message": "Отличная работа! Пока ждёшь модерацию — попробуй Studio AI.", "type": "success"}',
   'Релиз отправлен', 'Поздравление при отправке релиза'),

  ('drop_off', NULL, '{"screen": "/releases", "max_progress": 50}', 'notify',
   '{"title": "Продолжи релиз", "message": "Ты начал создавать релиз — осталось совсем немного!", "type": "system"}',
   'Брошенный релиз', 'Напоминание о незавершённом релизе'),

  ('success', 'subscription_changed', '{}', 'notify',
   '{"title": "Добро пожаловать в новый план!", "message": "Теперь тебе доступны все возможности. Начни с Studio AI!", "type": "success"}',
   'Подписка активирована', 'Приветствие при смене плана')
ON CONFLICT DO NOTHING;
