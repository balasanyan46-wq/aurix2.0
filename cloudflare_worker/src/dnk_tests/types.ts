export interface DnkTestsEnv {
  OPENAI_API_KEY?: string;
  DNK_OPENAI_API_KEY?: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  AURIX_CACHE: KVNamespace;
  ENV?: string;
  ALLOWED_ORIGINS?: string;
}

export type DnkTestSlug =
  | "artist_archetype"
  | "tone_communication"
  | "story_core"
  | "growth_profile"
  | "discipline_index"
  | "career_risk";

export type QuestionType = "scale" | "forced_choice" | "sjt" | "open";

export interface ScaleConfig {
  min: number;
  max: number;
  labels?: string[];
}

export interface QuestionOption {
  id: string;
  label: string;
  axis_weights: Record<string, number>;
}

export interface FollowupRule {
  if_axis_uncertain?: string;
  if_axis_conflict?: string[];
  ask: string[];
}

export interface TestQuestion {
  id: string;
  test_slug: DnkTestSlug;
  type: QuestionType;
  text: string;
  scale?: ScaleConfig;
  options?: QuestionOption[];
  axis_weights: Record<string, number>;
  followup_rules?: FollowupRule[];
}

export interface TestDef {
  slug: DnkTestSlug;
  title: string;
  description: string;
  whatGives: string;
  exampleResult: string;
  axes: string[];
}

export interface AxisAccum {
  sum: number;
  count: number;
  max_abs: number;
}

export interface TestComputedResult {
  score_axes: Record<string, number>;
  summary: string;
  strengths: string[];
  risks: string[];
  actions_7_days: string[];
  content_prompts: string[];
}
