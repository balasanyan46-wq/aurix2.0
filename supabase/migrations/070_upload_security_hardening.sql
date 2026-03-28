-- 1. Entity linking: connect uploaded files to their parent entity
ALTER TABLE uploaded_files
  ADD COLUMN IF NOT EXISTS entity_type text,
  ADD COLUMN IF NOT EXISTS entity_id   text;

CREATE INDEX idx_uploaded_files_entity
  ON uploaded_files(entity_type, entity_id)
  WHERE entity_type IS NOT NULL;

-- Backfill entity links for covers → releases
UPDATE uploaded_files uf
SET entity_type = 'release',
    entity_id   = r.id::text
FROM releases r
JOIN artists a ON a.id = r.artist_id
WHERE uf.folder = 'covers'
  AND uf.user_id = a.user_id
  AND r.cover_url LIKE '%' || uf.file_key
  AND uf.entity_type IS NULL;

-- Backfill entity links for tracks → tracks
UPDATE uploaded_files uf
SET entity_type = 'track',
    entity_id   = t.id::text
FROM tracks t
JOIN releases r ON r.id = t.release_id
JOIN artists a ON a.id = r.artist_id
WHERE uf.folder = 'tracks'
  AND uf.user_id = a.user_id
  AND t.audio_url LIKE '%' || uf.file_key
  AND uf.entity_type IS NULL;

-- 2. Security audit log
CREATE TABLE IF NOT EXISTS security_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     integer,
  ip          inet,
  action      text NOT NULL,
  resource    text,
  risk_level  text NOT NULL DEFAULT 'low'
                CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  detail      jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_security_logs_user ON security_logs(user_id, created_at DESC);
CREATE INDEX idx_security_logs_risk ON security_logs(risk_level, created_at DESC)
  WHERE risk_level IN ('high', 'critical');

-- 3. User-level delete cooldown (auto-block)
ALTER TABLE uploaded_files
  ADD COLUMN IF NOT EXISTS delete_blocked_until timestamptz;

-- Helper: add delete_blocked_until to users if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'delete_blocked_until'
  ) THEN
    ALTER TABLE profiles ADD COLUMN delete_blocked_until timestamptz;
  END IF;
END$$;
