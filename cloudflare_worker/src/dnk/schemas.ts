import { z } from "zod";

// ── Shared ──────────────────────────────────────────────────
const axisInt = z.number().int().min(-10).max(10);
const unitFloat = z.number().min(0).max(1);

const AxesAdjustmentsSchema = z.object({
  energy: axisInt,
  novelty: axisInt,
  darkness: axisInt,
  lyric_focus: axisInt,
  structure: axisInt,
  conflict_style: axisInt,
  publicness: axisInt,
  commercial_focus: axisInt,
});

const SocialAdjustmentsSchema = z.object({
  warmth: axisInt,
  power: axisInt,
  edge: axisInt,
  clarity: axisInt,
});

// ── Extract Features ────────────────────────────────────────
export const ExtractFeaturesSchema = z.object({
  tags: z.array(z.string()),
  axis_adjustments: AxesAdjustmentsSchema,
  social_adjustments: SocialAdjustmentsSchema,
  red_flags: z.object({
    social_desirability: unitFloat,
    low_effort: unitFloat,
    inconsistency: unitFloat,
  }),
  notes: z.string(),
});

export type ExtractFeatures = z.infer<typeof ExtractFeaturesSchema>;

// ── Social Summary (part of generate_profile) ───────────────
const ScriptsSchema = z.object({
  hate_reply: z.array(z.string()),
  interview_style: z.array(z.string()),
  conflict_style: z.array(z.string()),
  teamwork_rule: z.array(z.string()),
});

const SocialSummarySchema = z.object({
  magnets: z.array(z.string()),
  repellers: z.array(z.string()),
  people_come_for: z.string(),
  people_leave_when: z.string(),
  taboos: z.array(z.string()),
  scripts: ScriptsSchema,
});

// ── Generate Profile ────────────────────────────────────────
const bpm = z.number().int().min(60).max(180);

const MusicSchema = z.object({
  genres: z.array(z.string()),
  tempo_range_bpm: z.tuple([bpm, bpm]),
  mood: z.array(z.string()),
  lyrics: z.array(z.string()),
  do: z.array(z.string()),
  avoid: z.array(z.string()),
});

const ContentSchema = z.object({
  platform_focus: z.array(z.string()),
  content_pillars: z.array(z.string()),
  posting_rhythm: z.string(),
  hooks: z.array(z.string()),
  do: z.array(z.string()),
  avoid: z.array(z.string()),
});

const BehaviorSchema = z.object({
  teamwork: z.array(z.string()),
  conflict_style: z.string(),
  public_replies: z.array(z.string()),
  stress_protocol: z.array(z.string()),
});

const VisualSchema = z.object({
  palette: z.array(z.string()),
  materials: z.array(z.string()),
  references: z.array(z.string()),
  wardrobe: z.array(z.string()),
  do: z.array(z.string()),
  avoid: z.array(z.string()),
});

// ── Passport Hero (structured sections A–G) ────────────────
const PassportHeroSchema = z.object({
  hook: z.string(),
  how_people_feel_you: z.string(),
  magnet: z.array(z.string()),
  repulsion: z.array(z.string()),
  shadow: z.string(),
  taboo: z.array(z.string()),
  next_7_days: z.array(z.string()),
});

export const GenerateProfileSchema = z.object({
  profile_short: z.string(),
  profile_full: z.string(),
  passport_hero: PassportHeroSchema,
  recommendations: z.object({
    music: MusicSchema,
    content: ContentSchema,
    behavior: BehaviorSchema,
    visual: VisualSchema,
  }),
  prompts: z.object({
    track_concept: z.string(),
    lyrics_seed: z.string(),
    cover_prompt: z.string(),
    reels_series: z.string(),
  }),
  social_summary: SocialSummarySchema,
});

export type GenerateProfile = z.infer<typeof GenerateProfileSchema>;

// Re-export axes type for convenience
export const AxesSchema = z.object({
  energy: z.number().min(0).max(100),
  novelty: z.number().min(0).max(100),
  darkness: z.number().min(0).max(100),
  lyric_focus: z.number().min(0).max(100),
  structure: z.number().min(0).max(100),
  conflict_style: z.number().min(0).max(100),
  publicness: z.number().min(0).max(100),
  commercial_focus: z.number().min(0).max(100),
});

export type Axes = z.infer<typeof AxesSchema>;

export const SocialAxesSchema = z.object({
  warmth: z.number().min(0).max(100),
  power: z.number().min(0).max(100),
  edge: z.number().min(0).max(100),
  clarity: z.number().min(0).max(100),
});

export type SocialAxes = z.infer<typeof SocialAxesSchema>;
