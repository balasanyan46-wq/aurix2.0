-- T-Bank (Tinkoff) payment integration tables
-- Run: docker exec -i aurix_postgres psql -U aurix -d aurixdb < sql/005_tbank_payments.sql

CREATE TABLE IF NOT EXISTS payments (
  id            SERIAL PRIMARY KEY,
  user_id       INTEGER NOT NULL REFERENCES users(id),
  plan          VARCHAR(32)  NOT NULL,              -- start | breakthrough | empire
  billing_period VARCHAR(16) NOT NULL DEFAULT 'monthly', -- monthly | yearly
  amount        INTEGER      NOT NULL,              -- kopecks (e.g. 99000 = 990 RUB)
  status        VARCHAR(16)  NOT NULL DEFAULT 'pending', -- pending | confirmed | failed | refunded
  order_id      VARCHAR(128) NOT NULL UNIQUE,       -- userId_plan_timestamp
  tbank_payment_id VARCHAR(64),                     -- PaymentId from T-Bank response
  payment_url   TEXT,                               -- PaymentURL for redirect
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  confirmed_at  TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

CREATE TABLE IF NOT EXISTS subscription_log (
  id         SERIAL PRIMARY KEY,
  user_id    INTEGER NOT NULL REFERENCES users(id),
  action     VARCHAR(32)  NOT NULL,  -- activated | expired | upgraded | downgraded | cancelled
  plan       VARCHAR(32),
  payment_id INTEGER REFERENCES payments(id),
  meta       JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscription_log_user_id ON subscription_log(user_id);

-- Add plan-specific columns to profiles if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'subscription_end') THEN
    ALTER TABLE profiles ADD COLUMN subscription_end TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'subscription_status') THEN
    ALTER TABLE profiles ADD COLUMN subscription_status VARCHAR(16) DEFAULT 'none';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'plan') THEN
    ALTER TABLE profiles ADD COLUMN plan VARCHAR(32) DEFAULT 'start';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'plan_id') THEN
    ALTER TABLE profiles ADD COLUMN plan_id VARCHAR(32) DEFAULT 'start';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'billing_period') THEN
    ALTER TABLE profiles ADD COLUMN billing_period VARCHAR(16) DEFAULT 'monthly';
  END IF;
END $$;
