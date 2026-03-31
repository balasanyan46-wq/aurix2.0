-- Fix: new users must start on 'free' plan with no active subscription.
-- Run: docker exec -i aurix_postgres psql -U aurix -d aurixdb < sql/007_free_plan_defaults.sql

-- 1) Change column defaults
ALTER TABLE profiles ALTER COLUMN plan SET DEFAULT 'free';
ALTER TABLE profiles ALTER COLUMN plan_id SET DEFAULT 'free';
ALTER TABLE profiles ALTER COLUMN subscription_status SET DEFAULT 'none';

-- 2) Add free plan to plan_limits (3 AI requests, no video/analytics)
INSERT INTO plan_limits (plan, ai_requests, video_gen, analytics_q)
VALUES ('free', 3, 0, 0)
ON CONFLICT (plan) DO NOTHING;
