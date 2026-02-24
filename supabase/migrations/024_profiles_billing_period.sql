-- Add billing_period to profiles: 'monthly' (default) or 'yearly'
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS billing_period text NOT NULL DEFAULT 'monthly';
