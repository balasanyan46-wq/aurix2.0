-- ═══════════════════════════════════════════════════════
--  010: Referral System with passive income (10% forever)
-- ═══════════════════════════════════════════════════════

-- Referral codes — each user gets a unique code
CREATE TABLE IF NOT EXISTS referral_codes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code VARCHAR(32) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);

-- Track who referred whom
ALTER TABLE users ADD COLUMN IF NOT EXISTS referred_by INTEGER REFERENCES users(id);

-- Referral rewards — log of every reward paid out
CREATE TABLE IF NOT EXISTS referral_rewards (
  id SERIAL PRIMARY KEY,
  referrer_id INTEGER NOT NULL REFERENCES users(id),
  referred_id INTEGER NOT NULL REFERENCES users(id),
  payment_amount INTEGER NOT NULL,         -- original payment amount in rubles
  reward_amount INTEGER NOT NULL,          -- 10% of payment_amount
  payment_type VARCHAR(64) NOT NULL,       -- 'subscription', 'credits', 'beat_purchase', etc.
  payment_ref VARCHAR(128),                -- reference to original payment ID
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_referrer ON referral_rewards(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_referred ON referral_rewards(referred_id);

-- Add referral_earnings to user_balance
ALTER TABLE user_balance ADD COLUMN IF NOT EXISTS referral_earnings INTEGER DEFAULT 0;
