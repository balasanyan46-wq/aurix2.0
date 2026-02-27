import type { z } from "zod";
import type { LLMProvider, LLMCallOptions } from "./types";

// ── Schema hints for the repair prompt ──────────────────────

export const EXTRACT_FEATURES_HINT = [
  "tags: string[] (8-20 items)",
  "axis_adjustments: { energy: int[-10..10], novelty: int[-10..10], darkness: int[-10..10], lyric_focus: int[-10..10], structure: int[-10..10], conflict_style: int[-10..10], publicness: int[-10..10], commercial_focus: int[-10..10] }",
  "social_adjustments: { warmth: int[-10..10], power: int[-10..10], edge: int[-10..10], clarity: int[-10..10] }",
  "red_flags: { social_desirability: float[0..1], low_effort: float[0..1], inconsistency: float[0..1] }",
  "notes: string",
].join("\n");

export const GENERATE_PROFILE_HINT = [
  "profile_short: string",
  "profile_full: string",
  "passport_hero: {",
  "  hook: string, how_people_feel_you: string,",
  "  magnet: string[] (2-3 items), repulsion: string[] (2-3 items),",
  "  shadow: string, taboo: string[] (3-5 items), next_7_days: string[] (3 items)",
  "}",
  "recommendations: {",
  "  music: { genres: string[], tempo_range_bpm: [int 60..180, int 60..180] (first<=second), mood: string[], lyrics: string[], do: string[], avoid: string[] }",
  "  content: { platform_focus: string[], content_pillars: string[], posting_rhythm: string, hooks: string[], do: string[], avoid: string[] }",
  "  behavior: { teamwork: string[], conflict_style: string, public_replies: string[], stress_protocol: string[] }",
  "  visual: { palette: string[], materials: string[], references: string[], wardrobe: string[], do: string[], avoid: string[] }",
  "}",
  "prompts: { track_concept: string, lyrics_seed: string, cover_prompt: string, reels_series: string }",
  "social_summary: {",
  "  magnets: string[3], repellers: string[3], people_come_for: string, people_leave_when: string,",
  "  taboos: string[5],",
  "  scripts: { hate_reply: string[2], interview_style: string[1], conflict_style: string[1], teamwork_rule: string[1] }",
  "}",
].join("\n");

// ── Repair system prompt ────────────────────────────────────

const REPAIR_SYSTEM_PROMPT = `You are a strict JSON repair bot.
You receive a raw LLM output that failed schema validation and a schema_hint describing the expected structure.

RULES:
- Return ONLY valid JSON matching the schema_hint. No markdown, no comments, no extra text.
- Do NOT invent new data. Keep all existing values from the raw output.
- If a required key is missing, add it with sensible defaults:
  - missing string → ""
  - missing string[] → []
  - missing number → 0
  - missing object → fill all sub-keys with defaults
- Fix type mismatches:
  - string numbers like "5" → 5 (for numeric fields)
  - float where int expected → Math.round
  - negative where positive expected → clamp to range
- tempo_range_bpm must be [int 60..180, int 60..180] with first <= second.
  If values are outside range, clamp. If first > second, swap.
- axis_adjustments values must be integers in [-10, 10]. Clamp and round.
- social_adjustments values (warmth, power, edge, clarity) must be integers in [-10, 10]. Clamp and round.
- red_flags values must be floats in [0, 1]. Clamp.
- social_summary.magnets must have exactly 3 items, repellers exactly 3, taboos exactly 5.
- social_summary.scripts.hate_reply must have 2 items, interview_style 1, conflict_style 1, teamwork_rule 1.
- passport_hero must be an object with: hook (string), how_people_feel_you (string), magnet (string[], 2-3 items), repulsion (string[], 2-3 items), shadow (string), taboo (string[], 3-5 items), next_7_days (string[], exactly 3 items).
- If passport_hero is missing, create it with sensible defaults from profile_short.
- Strip any keys NOT in the schema_hint.
- Do NOT wrap output in markdown code blocks.
- Return ONLY the JSON object.`;

// ── Result type ─────────────────────────────────────────────

export interface RepairResult<T> {
  data: T;
  repaired: boolean;
  attempts: number;
}

// ── Main function ───────────────────────────────────────────

export async function callLLMWithAutoRepair<T>({
  provider,
  systemPrompt,
  userPayload,
  schema,
  schemaHint,
  maxRetries = 2,
  enableRepair = true,
  llmOpts,
}: {
  provider: LLMProvider;
  systemPrompt: string;
  userPayload: string;
  schema: z.ZodType<T>;
  schemaHint: string;
  maxRetries?: number;
  enableRepair?: boolean;
  llmOpts?: LLMCallOptions;
}): Promise<RepairResult<T>> {
  let lastError: Error | null = null;
  let totalAttempts = 0;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    totalAttempts++;

    let rawObj: unknown;
    try {
      const raw = await provider.generateJSON(systemPrompt, userPayload, llmOpts);
      rawObj = typeof raw === "string" ? JSON.parse(raw) : raw;
    } catch (e: any) {
      lastError = e;
      logError("LLM/parse", attempt, maxRetries, e);
      if (attempt < maxRetries) continue;
      break;
    }

    // Validate with Zod
    const parseResult = schema.safeParse(rawObj);
    if (parseResult.success) {
      return { data: parseResult.data, repaired: false, attempts: totalAttempts };
    }

    // Validation failed
    logZodError(attempt, maxRetries, parseResult.error);
    lastError = parseResult.error;

    // Attempt repair once (only on first validation failure, when repair is enabled)
    if (enableRepair && attempt === 0) {
      const repairResult = await tryRepair(provider, rawObj, schema, schemaHint);
      totalAttempts++;
      if (repairResult !== null) {
        console.log(`[DNK] Auto-repair succeeded (total attempts: ${totalAttempts})`);
        return { data: repairResult, repaired: true, attempts: totalAttempts };
      }
      console.log("[DNK] Auto-repair failed, continuing retries");
    }
  }

  throw lastError ?? new Error("LLM call failed after all retries + repair");
}

// ── Repair attempt ──────────────────────────────────────────

async function tryRepair<T>(
  provider: LLMProvider,
  rawObj: unknown,
  schema: z.ZodType<T>,
  schemaHint: string
): Promise<T | null> {
  try {
    const rawText = typeof rawObj === "string" ? rawObj : JSON.stringify(rawObj);

    const repairPayload = JSON.stringify({
      raw: rawText,
      schema_hint: schemaHint,
    });

    const repaired = await provider.generateJSON(REPAIR_SYSTEM_PROMPT, repairPayload);
    const repairedObj = typeof repaired === "string" ? JSON.parse(repaired) : repaired;

    const result = schema.safeParse(repairedObj);
    if (result.success) {
      return result.data;
    }

    logZodError(-1, 0, result.error, "repair");
    return null;
  } catch (e: any) {
    console.error(`[DNK] Repair LLM call failed: ${e.message ?? e}`);
    return null;
  }
}

// ── Logging helpers ─────────────────────────────────────────

function logError(phase: string, attempt: number, maxRetries: number, e: any): void {
  if (e instanceof SyntaxError) {
    console.error(
      `[DNK] JSON parse failed (attempt ${attempt + 1}/${maxRetries + 1}): ${e.message}`
    );
  } else {
    console.error(
      `[DNK] ${phase} failed (attempt ${attempt + 1}/${maxRetries + 1}): ${e.message ?? e}`
    );
  }
}

function logZodError(attempt: number, maxRetries: number, error: z.ZodError, phase = "validate"): void {
  const issues = (error as any).issues
    ?.slice(0, 4)
    .map((i: any) => `${i.path?.join(".") ?? "?"}: ${i.message}`)
    .join("; ");
  const label = phase === "repair"
    ? "[DNK] Repair Zod validation failed"
    : `[DNK] Zod validation failed (attempt ${attempt + 1}/${maxRetries + 1})`;
  console.error(`${label}: ${issues}`);
}
