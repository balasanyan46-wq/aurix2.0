-- Hit Predictor credit cost (10 credits)
INSERT INTO credit_costs (action_key, cost, label) VALUES
  ('ai_hit_predictor', 10, 'AI Hit Predictor')
ON CONFLICT (action_key) DO NOTHING;
