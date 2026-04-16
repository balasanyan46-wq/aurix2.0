-- AI Studio session history
CREATE TABLE IF NOT EXISTS studio_sessions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  beat_filename TEXT,
  style TEXT NOT NULL DEFAULT 'wide_star',
  autotune BOOLEAN DEFAULT TRUE,
  autotune_strength REAL DEFAULT 0.5,
  autotune_key TEXT DEFAULT 'C_major',
  target TEXT DEFAULT 'spotify',
  duration REAL,
  processing_time REAL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_studio_sessions_user ON studio_sessions(user_id, created_at DESC);
