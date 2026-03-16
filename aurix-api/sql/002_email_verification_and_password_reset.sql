-- Rename email_verified → verified, add reset token columns
-- Idempotent: safe to run multiple times

-- 1. Add 'verified' column if missing (mirrors email_verified)
ALTER TABLE users ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT false;

-- 2. Sync existing email_verified data into verified
UPDATE users SET verified = email_verified WHERE verified IS DISTINCT FROM email_verified;

-- 3. Add verification_token (rename from email_verification_token)
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_token TEXT;

-- 4. Copy existing tokens
UPDATE users SET verification_token = email_verification_token
  WHERE verification_token IS NULL AND email_verification_token IS NOT NULL;

-- 5. Add password reset columns
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_token_expires TIMESTAMPTZ;

-- 6. Index for fast token lookups
CREATE INDEX IF NOT EXISTS idx_users_verification_token ON users (verification_token) WHERE verification_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_reset_token ON users (reset_token) WHERE reset_token IS NOT NULL;
