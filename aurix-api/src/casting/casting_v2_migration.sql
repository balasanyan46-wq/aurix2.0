-- Migration v2: Add payment columns to casting_applications
ALTER TABLE casting_applications ADD COLUMN IF NOT EXISTS plan VARCHAR(20) DEFAULT 'base';
ALTER TABLE casting_applications ADD COLUMN IF NOT EXISTS order_id VARCHAR(100);
ALTER TABLE casting_applications ADD COLUMN IF NOT EXISTS amount BIGINT DEFAULT 0;
ALTER TABLE casting_applications ADD COLUMN IF NOT EXISTS tbank_payment_id VARCHAR(100);
ALTER TABLE casting_applications ADD COLUMN IF NOT EXISTS payment_url TEXT;
ALTER TABLE casting_applications ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

-- Allow 'pending_payment', 'cancelled', 'paid' statuses
ALTER TABLE casting_applications DROP CONSTRAINT IF EXISTS casting_applications_status_check;
ALTER TABLE casting_applications ADD CONSTRAINT casting_applications_status_check
  CHECK (status IN ('pending_payment', 'paid', 'approved', 'rejected', 'invited', 'cancelled', 'new'));

CREATE INDEX IF NOT EXISTS idx_casting_order_id ON casting_applications(order_id);
