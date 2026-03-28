-- ============================================================
-- 064 · User Events — track all meaningful user actions
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_events (
  id          bigserial    PRIMARY KEY,
  user_id     int          NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event       text         NOT NULL,            -- e.g. 'login', 'release_created', 'track_uploaded', 'ai_chat', 'subscription_changed'
  target_type text,                             -- e.g. 'release', 'track', 'ticket', 'subscription'
  target_id   text,                             -- polymorphic ID (string for uuid compat)
  meta        jsonb        DEFAULT '{}',        -- arbitrary payload
  ip          text,
  user_agent  text,
  created_at  timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_events_user      ON public.user_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_events_event     ON public.user_events(event, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_events_created   ON public.user_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_events_target    ON public.user_events(target_type, target_id);

-- Handy view: daily active users
CREATE OR REPLACE VIEW public.v_dau AS
SELECT
  date_trunc('day', created_at)::date AS day,
  count(DISTINCT user_id)             AS dau
FROM public.user_events
GROUP BY 1
ORDER BY 1 DESC;

-- Handy view: monthly active users
CREATE OR REPLACE VIEW public.v_mau AS
SELECT
  date_trunc('month', created_at)::date AS month,
  count(DISTINCT user_id)               AS mau
FROM public.user_events
GROUP BY 1
ORDER BY 1 DESC;

-- Funnel view: key events count per user (for conversion analysis)
CREATE OR REPLACE VIEW public.v_user_funnel AS
SELECT
  user_id,
  count(*) FILTER (WHERE event = 'login')               AS logins,
  count(*) FILTER (WHERE event = 'release_created')      AS releases_created,
  count(*) FILTER (WHERE event = 'track_uploaded')       AS tracks_uploaded,
  count(*) FILTER (WHERE event = 'ai_chat')              AS ai_chats,
  count(*) FILTER (WHERE event = 'subscription_changed') AS sub_changes,
  min(created_at)                                        AS first_event,
  max(created_at)                                        AS last_event
FROM public.user_events
GROUP BY user_id;
