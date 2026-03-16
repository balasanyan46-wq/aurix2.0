import { z } from "zod";

const bounded = z.number().int().min(-12).max(12);
const unit = z.number().min(0).max(1);

export const ExtractTestFeaturesSchema = z.object({
  tags: z.array(z.string()).max(24).default([]),
  axis_adjustments: z.record(z.string(), bounded).default({}),
  red_flags: z.object({
    social_desirability: unit.default(0),
    low_effort: unit.default(0),
    inconsistency: unit.default(0),
  }).default({
    social_desirability: 0,
    low_effort: 0,
    inconsistency: 0,
  }),
  notes: z.string().default(""),
});

export const TestResultSchema = z.object({
  score_axes: z.record(z.string(), z.number().min(0).max(100)),
  summary: z.string(),
  strengths: z.array(z.string()),
  risks: z.array(z.string()),
  actions_7_days: z.array(z.string()),
  content_prompts: z.array(z.string()),
});

export type ExtractTestFeatures = z.infer<typeof ExtractTestFeaturesSchema>;
export type TestResultPayload = z.infer<typeof TestResultSchema>;

export const EXTRACT_TEST_FEATURES_HINT = [
  "tags: string[] (6..20)",
  "axis_adjustments: record(axisName -> int[-12..12])",
  "red_flags: { social_desirability: float[0..1], low_effort: float[0..1], inconsistency: float[0..1] }",
  "notes: string",
].join("\n");

export const TEST_RESULT_HINT = [
  "score_axes: record(axisName -> 0..100)",
  "summary: string",
  "strengths: string[]",
  "risks: string[]",
  "actions_7_days: string[]",
  "content_prompts: string[]",
].join("\n");
