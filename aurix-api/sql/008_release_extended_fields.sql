-- 008: Extended release fields — services, pricing, lyrics, platform links, extra metadata
-- Safe to re-run: all statements use IF NOT EXISTS / ADD COLUMN IF NOT EXISTS

-- New columns on releases
ALTER TABLE releases ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE releases ADD COLUMN IF NOT EXISTS lyrics TEXT;
ALTER TABLE releases ADD COLUMN IF NOT EXISTS copyright_holders TEXT; -- JSON string: [{name, role, share}]
ALTER TABLE releases ADD COLUMN IF NOT EXISTS platform_links JSONB DEFAULT '{}'; -- {spotify: url, apple: url, ...}
ALTER TABLE releases ADD COLUMN IF NOT EXISTS services JSONB DEFAULT '[]'; -- [{id, name, price, enabled}]
ALTER TABLE releases ADD COLUMN IF NOT EXISTS total_price NUMERIC(10,2) DEFAULT 0;
ALTER TABLE releases ADD COLUMN IF NOT EXISTS bpm INTEGER;
ALTER TABLE releases ADD COLUMN IF NOT EXISTS mood TEXT; -- e.g. "energetic", "chill", "dark"
ALTER TABLE releases ADD COLUMN IF NOT EXISTS target_audience TEXT;
ALTER TABLE releases ADD COLUMN IF NOT EXISTS reference_tracks TEXT; -- comma-separated or JSON
ALTER TABLE releases ADD COLUMN IF NOT EXISTS tiktok_clip BOOLEAN DEFAULT false;
ALTER TABLE releases ADD COLUMN IF NOT EXISTS ai_generated JSONB DEFAULT '{}'; -- {title: bool, description: bool, lyrics_checked: bool}
ALTER TABLE releases ADD COLUMN IF NOT EXISTS needs_revision BOOLEAN DEFAULT false;
ALTER TABLE releases ADD COLUMN IF NOT EXISTS revision_reason TEXT;
ALTER TABLE releases ADD COLUMN IF NOT EXISTS wizard_step INTEGER DEFAULT 0; -- last completed step (for autosave)

-- Add lyrics column to tracks table for per-track lyrics
ALTER TABLE tracks ADD COLUMN IF NOT EXISTS lyrics TEXT;
ALTER TABLE tracks ADD COLUMN IF NOT EXISTS bpm INTEGER;
ALTER TABLE tracks ADD COLUMN IF NOT EXISTS mood TEXT;

-- Update status check to include new statuses
-- (No constraint to alter — status is a text field with application-level validation)
