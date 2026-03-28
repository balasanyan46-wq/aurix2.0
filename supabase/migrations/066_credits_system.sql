-- ============================================================
-- 066: Credits / Monetization System
-- ============================================================

-- User balance (one row per user)
CREATE TABLE IF NOT EXISTS user_balance (
  user_id   INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  credits   INT NOT NULL DEFAULT 0 CHECK (credits >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Transaction log
CREATE TABLE IF NOT EXISTS credit_transactions (
  id         SERIAL PRIMARY KEY,
  user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type       VARCHAR(20) NOT NULL CHECK (type IN ('spend','topup','bonus','plan_grant','refund')),
  amount     INT NOT NULL,  -- positive for topup/bonus, negative for spend
  balance_after INT NOT NULL,
  reason     VARCHAR(255),
  meta       JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_credit_tx_user ON credit_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_credit_tx_type ON credit_transactions(type);

-- Credit cost config (editable from admin)
CREATE TABLE IF NOT EXISTS credit_costs (
  action_key VARCHAR(50) PRIMARY KEY,  -- 'ai_chat','ai_cover','ai_video','ai_music'
  cost       INT NOT NULL DEFAULT 1,
  label      VARCHAR(100),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Plan credit grants
CREATE TABLE IF NOT EXISTS plan_credits (
  plan_id    VARCHAR(30) PRIMARY KEY,  -- 'start','breakthrough','empire'
  credits    INT NOT NULL DEFAULT 0,
  label      VARCHAR(100)
);

-- Seed costs
INSERT INTO credit_costs (action_key, cost, label) VALUES
  ('ai_chat',    1,  'AI чат / текст'),
  ('ai_cover',   3,  'AI обложка'),
  ('ai_video',   5,  'AI видео'),
  ('ai_music',  10,  'AI музыка')
ON CONFLICT (action_key) DO NOTHING;

-- Seed plan credits
INSERT INTO plan_credits (plan_id, credits, label) VALUES
  ('start',        50,  'Старт'),
  ('breakthrough', 200, 'Прорыв'),
  ('empire',       500, 'Империя')
ON CONFLICT (plan_id) DO NOTHING;
