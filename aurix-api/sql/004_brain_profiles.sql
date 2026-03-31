-- Brain profiles: behavioral analytics per user
CREATE TABLE IF NOT EXISTS user_brain_profiles (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  activity_level TEXT NOT NULL DEFAULT 'low',
  content_focus TEXT NOT NULL DEFAULT 'none',
  promo_usage BOOLEAN NOT NULL DEFAULT false,
  ai_usage BOOLEAN NOT NULL DEFAULT false,
  last_release_days INTEGER,
  growth_status TEXT NOT NULL DEFAULT 'new',
  top_events TEXT[] DEFAULT '{}',
  events_7d INTEGER NOT NULL DEFAULT 0,
  events_30d INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_brain_profiles_activity ON user_brain_profiles(activity_level);
CREATE INDEX IF NOT EXISTS idx_brain_profiles_growth ON user_brain_profiles(growth_status);

-- Brain strategies: cached AI-generated strategy per user
CREATE TABLE IF NOT EXISTS user_brain_strategies (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  strategy_json JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
