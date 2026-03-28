-- System logs table for monitoring, error tracking, and self-healing audit trail
CREATE TABLE IF NOT EXISTS system_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  message text NOT NULL,
  data jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_system_logs_type ON system_logs (type);
CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON system_logs (created_at DESC);

-- Auto-cleanup: keep only last 30 days of system logs
CREATE OR REPLACE FUNCTION cleanup_old_system_logs()
RETURNS void LANGUAGE sql AS $$
  DELETE FROM system_logs WHERE created_at < now() - interval '30 days';
$$;
