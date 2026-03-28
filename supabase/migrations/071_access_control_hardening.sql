-- 1. Signed URL access log — tracks downloads per user with quotas
CREATE TABLE IF NOT EXISTS signed_url_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     integer NOT NULL,
  file_key    text NOT NULL,
  folder      text NOT NULL,
  ip          inet,
  user_agent  text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_signed_url_log_user_hour
  ON signed_url_log(user_id, created_at DESC);

CREATE INDEX idx_signed_url_log_user_day
  ON signed_url_log(user_id, (created_at::date));

-- 2. Device tracking
CREATE TABLE IF NOT EXISTS user_devices (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ip            inet NOT NULL,
  user_agent    text,
  fingerprint   text,
  first_seen    timestamptz NOT NULL DEFAULT now(),
  last_seen     timestamptz NOT NULL DEFAULT now(),
  is_suspicious boolean NOT NULL DEFAULT false,
  note          text,
  UNIQUE (user_id, ip, fingerprint)
);

CREATE INDEX idx_user_devices_user ON user_devices(user_id);
CREATE INDEX idx_user_devices_suspicious ON user_devices(user_id)
  WHERE is_suspicious = true;

-- 3. Access restriction flag on profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS file_access_blocked_until timestamptz;
