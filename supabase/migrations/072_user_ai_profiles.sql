-- User AI profiles — optional artist identity for personalized AI responses.
-- Stored server-side so context is available across devices.

CREATE TABLE IF NOT EXISTS user_ai_profiles (
  user_id   INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  name      TEXT NOT NULL DEFAULT '',
  genre     TEXT NOT NULL DEFAULT '',
  mood      TEXT NOT NULL DEFAULT '',
  references_list TEXT[] NOT NULL DEFAULT '{}',
  goals     TEXT[] NOT NULL DEFAULT '{}',
  style_description TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_ai_profiles_user ON user_ai_profiles(user_id);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_user_ai_profile_ts()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_ai_profile_ts ON user_ai_profiles;
CREATE TRIGGER trg_user_ai_profile_ts
  BEFORE UPDATE ON user_ai_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_user_ai_profile_ts();
