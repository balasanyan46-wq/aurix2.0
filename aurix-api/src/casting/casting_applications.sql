-- Migration: Create casting_applications table
CREATE TABLE IF NOT EXISTS casting_applications (
  id            SERIAL PRIMARY KEY,
  user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          VARCHAR(255) NOT NULL,
  artist_name   VARCHAR(255) NOT NULL,
  phone         VARCHAR(30)  NOT NULL,
  city          VARCHAR(100) NOT NULL,
  media_link    VARCHAR(1000) NOT NULL,
  about         TEXT,
  status        VARCHAR(20) NOT NULL DEFAULT 'new'
                CHECK (status IN ('new', 'approved', 'rejected', 'invited')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_casting_user_id ON casting_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_casting_status  ON casting_applications(status);
CREATE INDEX IF NOT EXISTS idx_casting_city    ON casting_applications(city);
CREATE INDEX IF NOT EXISTS idx_casting_created ON casting_applications(created_at DESC);
