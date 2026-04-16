-- Track analysis history — stores full results so users can revisit
CREATE TABLE IF NOT EXISTS track_analyses (
  id            SERIAL PRIMARY KEY,
  user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  filename      VARCHAR(255) NOT NULL DEFAULT 'track',
  genre         VARCHAR(100),
  bpm           REAL,
  key           VARCHAR(10),
  duration      REAL,
  hit_score     INTEGER,
  score         REAL,
  viral_probability INTEGER,
  audio_metrics JSONB NOT NULL DEFAULT '{}',
  lyrics_analysis JSONB,
  ai_analysis   JSONB NOT NULL DEFAULT '{}',
  lyrics        TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_track_analyses_user ON track_analyses(user_id, created_at DESC);
