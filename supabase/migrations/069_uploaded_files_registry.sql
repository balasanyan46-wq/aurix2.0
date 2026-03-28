-- uploaded_files: authoritative ownership registry for S3 objects
CREATE TABLE IF NOT EXISTS uploaded_files (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_key    text NOT NULL UNIQUE,
  folder      text NOT NULL CHECK (folder IN ('covers', 'tracks', 'production')),
  mime_type   text,
  size_bytes  bigint,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_uploaded_files_user   ON uploaded_files(user_id);
CREATE INDEX idx_uploaded_files_key    ON uploaded_files(file_key);

-- deleted_files: soft-delete audit log, S3 purge deferred 24h
CREATE TABLE IF NOT EXISTS deleted_files (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     integer NOT NULL,
  file_key    text NOT NULL,
  folder      text NOT NULL,
  deleted_at  timestamptz NOT NULL DEFAULT now(),
  purge_after timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
  purged      boolean NOT NULL DEFAULT false
);

CREATE INDEX idx_deleted_files_purge ON deleted_files(purge_after) WHERE NOT purged;

-- Backfill: register existing cover files
INSERT INTO uploaded_files (user_id, file_key, folder)
SELECT a.user_id,
       substring(r.cover_url FROM '/storage/(.+)$'),
       'covers'
FROM releases r
JOIN artists a ON a.id = r.artist_id
WHERE r.cover_url IS NOT NULL
  AND r.cover_url LIKE '%/storage/%'
ON CONFLICT (file_key) DO NOTHING;

-- Backfill: register existing track audio files
INSERT INTO uploaded_files (user_id, file_key, folder)
SELECT a.user_id,
       substring(t.audio_url FROM '/storage/(.+)$'),
       'tracks'
FROM tracks t
JOIN releases r ON r.id = t.release_id
JOIN artists a ON a.id = r.artist_id
WHERE t.audio_url IS NOT NULL
  AND t.audio_url LIKE '%/storage/%'
ON CONFLICT (file_key) DO NOTHING;
