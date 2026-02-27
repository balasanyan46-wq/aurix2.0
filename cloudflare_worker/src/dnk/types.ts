// ── Env extensions ──────────────────────────────────────────
export interface DnkEnv {
  OPENAI_API_KEY?: string;
  DNK_OPENAI_API_KEY?: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  AURIX_CACHE: KVNamespace;
}

// ── Question bank types ─────────────────────────────────────
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

export interface DnkQuestion {
  id: string;
  type: QuestionType;
  text: string;
  scale?: ScaleConfig;
  options?: QuestionOption[];
  axis_weights: Record<string, number>;
  followup_rules?: FollowupRule[];
}

// ── Axis names ──────────────────────────────────────────────
export const AXIS_NAMES = [
  "energy",
  "novelty",
  "darkness",
  "lyric_focus",
  "structure",
  "conflict_style",
  "publicness",
  "commercial_focus",
] as const;

export type AxisName = (typeof AXIS_NAMES)[number];

// ── Social magnetism axes ───────────────────────────────────
export const SOCIAL_AXIS_NAMES = [
  "warmth",
  "power",
  "edge",
  "clarity",
] as const;

export type SocialAxisName = (typeof SOCIAL_AXIS_NAMES)[number];

// ── Answer payload (stored in answer_json) ──────────────────
export interface ScaleAnswer {
  value: number; // 1..5
}
export interface ChoiceAnswer {
  key: string; // option id: "A" | "B" | "C" | "D"
}
export interface OpenAnswer {
  text: string;
}

// ── Scoring result ──────────────────────────────────────────
export interface AxesScores {
  [axis: string]: number; // 0..100
}

export interface ConfidenceScores {
  [axis: string]: number; // 0..1
}

// ── Running accumulator (for followup evaluation) ───────────
export interface AxisAccum {
  sum: number;
  count: number;
}

// ── LLM output schemas ─────────────────────────────────────
export interface ExtractFeaturesResult {
  tags: string[];
  axis_adjustments: Record<string, number>;
  social_adjustments: Record<string, number>;
  red_flags: {
    social_desirability: number;
    low_effort: number;
    inconsistency: number;
  };
  notes: string;
}

export interface GenerateProfileResult {
  profile_short: string;
  profile_full: string;
  recommendations: {
    music: {
      genres: string[];
      tempo_range_bpm: [number, number];
      mood: string[];
      lyrics: string[];
      do: string[];
      avoid: string[];
    };
    content: {
      platform_focus: string[];
      content_pillars: string[];
      posting_rhythm: string;
      hooks: string[];
      do: string[];
      avoid: string[];
    };
    behavior: {
      teamwork: string[];
      conflict_style: string;
      public_replies: string[];
      stress_protocol: string[];
    };
    visual: {
      palette: string[];
      materials: string[];
      references: string[];
      wardrobe: string[];
      do: string[];
      avoid: string[];
    };
  };
  prompts: {
    track_concept: string;
    lyrics_seed: string;
    cover_prompt: string;
    reels_series: string;
  };
  social_summary: {
    magnets: string[];
    repellers: string[];
    people_come_for: string;
    people_leave_when: string;
    taboos: string[];
    scripts: {
      hate_reply: string[];
      interview_style: string[];
      conflict_style: string[];
      teamwork_rule: string[];
    };
  };
}

// ── LLM call options ────────────────────────────────────────
export interface LLMCallOptions {
  timeoutMs?: number;
  maxTokens?: number;
}

// ── LLM Provider interface ──────────────────────────────────
export interface LLMProvider {
  generateJSON(systemPrompt: string, userPayload: string, opts?: LLMCallOptions): Promise<any>;
}
