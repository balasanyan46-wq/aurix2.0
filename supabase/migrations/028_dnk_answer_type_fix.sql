-- 028 · Fix dnk_answers answer_type constraint to match actual question types
ALTER TABLE public.dnk_answers DROP CONSTRAINT IF EXISTS dnk_answers_answer_type_check;
ALTER TABLE public.dnk_answers ADD CONSTRAINT dnk_answers_answer_type_check
  CHECK (answer_type IN ('scale','forced_choice','sjt','open'));
