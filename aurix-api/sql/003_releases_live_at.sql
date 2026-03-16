-- Add live_at column to releases table (for tracking when release goes live)
ALTER TABLE releases ADD COLUMN IF NOT EXISTS live_at TIMESTAMPTZ;
