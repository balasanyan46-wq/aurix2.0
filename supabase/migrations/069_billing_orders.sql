-- Billing orders: secure payment flow for credit purchases
CREATE TABLE IF NOT EXISTS billing_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id integer NOT NULL REFERENCES users(id),
  amount integer NOT NULL CHECK (amount > 0),
  credits integer NOT NULL CHECK (credits > 0),
  price_label text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'expired')),
  payment_method text,
  payment_ref text,
  confirmed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_billing_orders_user ON billing_orders (user_id);
CREATE INDEX IF NOT EXISTS idx_billing_orders_status ON billing_orders (status);

-- Auto-expire pending orders older than 30 minutes
CREATE OR REPLACE FUNCTION expire_stale_billing_orders()
RETURNS void LANGUAGE sql AS $$
  UPDATE billing_orders
  SET status = 'expired', updated_at = now()
  WHERE status = 'pending' AND created_at < now() - interval '30 minutes';
$$;
