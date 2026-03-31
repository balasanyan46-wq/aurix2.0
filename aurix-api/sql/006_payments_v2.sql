-- Payment system v2: recurring, credits purchase, cancellation, usage limits
-- Run: docker exec -i aurix_postgres psql -U aurix -d aurixdb < sql/006_payments_v2.sql

-- 1) Extend payments table
ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_type VARCHAR(16) NOT NULL DEFAULT 'subscription';
  -- subscription | credits
ALTER TABLE payments ADD COLUMN IF NOT EXISTS rebill_id TEXT;
  -- T-Bank RebillId for recurring charges
ALTER TABLE payments ADD COLUMN IF NOT EXISTS credits_amount INTEGER;
  -- How many credits were purchased (for type=credits)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS credit_package VARCHAR(16);
  -- small | medium | large (for type=credits)

-- 2) Extend profiles for cancellation
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS cancel_at_period_end BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_rebill_id TEXT;
  -- Most recent successful rebill_id for recurring

-- 3) Usage limits table (per billing period)
CREATE TABLE IF NOT EXISTS usage_limits (
  id           SERIAL PRIMARY KEY,
  user_id      INTEGER NOT NULL REFERENCES users(id),
  period_start DATE    NOT NULL DEFAULT CURRENT_DATE,
  ai_requests  INTEGER NOT NULL DEFAULT 0,
  video_gen    INTEGER NOT NULL DEFAULT 0,
  analytics_q  INTEGER NOT NULL DEFAULT 0,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, period_start)
);

CREATE INDEX IF NOT EXISTS idx_usage_limits_user ON usage_limits(user_id, period_start);

-- 4) Plan limits config table (admin-editable)
CREATE TABLE IF NOT EXISTS plan_limits (
  plan           VARCHAR(32) PRIMARY KEY,
  ai_requests    INTEGER NOT NULL DEFAULT 0,   -- 0 = unlimited
  video_gen      INTEGER NOT NULL DEFAULT 0,
  analytics_q    INTEGER NOT NULL DEFAULT 0,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO plan_limits (plan, ai_requests, video_gen, analytics_q)
VALUES
  ('start',        10,  0, 0),
  ('breakthrough', 100, 5, 50),
  ('empire',       0,   0, 0)   -- 0 = unlimited
ON CONFLICT (plan) DO NOTHING;
