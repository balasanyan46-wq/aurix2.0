import { AXIS_NAMES, SOCIAL_AXIS_NAMES } from "./types";
import type {
  AxesScores,
  ConfidenceScores,
  AxisAccum,
  DnkQuestion,
} from "./types";
import type { ExtractFeatures } from "./schemas";
import { getAllQuestionsMap } from "./questions";

interface AnswerRow {
  question_id: string;
  answer_type: string;
  answer_json: any;
}

// ─── Accumulate raw contributions ────────────────────────────

export function buildAccumulator(): Record<string, AxisAccum> {
  const accum: Record<string, AxisAccum> = {};
  for (const axis of AXIS_NAMES) {
    accum[axis] = { sum: 0, count: 0 };
  }
  return accum;
}

export function buildSocialAccumulator(): Record<string, AxisAccum> {
  const accum: Record<string, AxisAccum> = {};
  for (const axis of SOCIAL_AXIS_NAMES) {
    accum[axis] = { sum: 0, count: 0 };
  }
  return accum;
}

export function applyAnswer(
  accum: Record<string, AxisAccum>,
  q: DnkQuestion,
  answerType: string,
  answerJson: any
): void {
  if (answerType === "scale") {
    const value = answerJson?.value;
    if (typeof value !== "number") return;
    const delta = value - 3; // -2, -1, 0, 1, 2
    for (const [axis, weight] of Object.entries(q.axis_weights)) {
      if (accum[axis] === undefined) continue;
      accum[axis].sum += delta * weight;
      accum[axis].count += 1;
    }
  } else if (answerType === "forced_choice" || answerType === "sjt") {
    const key = answerJson?.key;
    if (typeof key !== "string" || !q.options) return;
    const opt = q.options.find((o) => o.id === key);
    if (!opt) return;
    for (const [axis, weight] of Object.entries(opt.axis_weights)) {
      if (accum[axis] === undefined) continue;
      accum[axis].sum += weight;
      accum[axis].count += 1;
    }
  }
}

// ─── Compute base axes from accumulator ──────────────────────

export function computeBaseAxes(answers: AnswerRow[]): AxesScores {
  const qMap = getAllQuestionsMap();
  const accum = buildAccumulator();

  for (const ans of answers) {
    const q = qMap.get(ans.question_id);
    if (!q) continue;
    applyAnswer(accum, q, ans.answer_type, ans.answer_json);
  }

  return axesFromAccum(accum);
}

export function axesFromAccum(accum: Record<string, AxisAccum>): AxesScores {
  const result: AxesScores = {};
  for (const axis of AXIS_NAMES) {
    result[axis] = Math.max(0, Math.min(100, Math.round(50 + accum[axis].sum)));
  }
  return result;
}

// ─── Merge axes with LLM adjustments ─────────────────────────

export function mergeWithAdjustments(
  base: AxesScores,
  adjustments: Record<string, number>
): AxesScores {
  const result: AxesScores = { ...base };
  for (const axis of AXIS_NAMES) {
    const delta = typeof adjustments[axis] === "number" ? adjustments[axis] : 0;
    const clamped = Math.max(-10, Math.min(10, delta));
    result[axis] = Math.max(0, Math.min(100, Math.round(result[axis] + clamped)));
  }
  return result;
}

// ─── Social axes scoring ────────────────────────────────────

export function computeSocialBaseAxes(answers: AnswerRow[]): AxesScores {
  const qMap = getAllQuestionsMap();
  const accum = buildSocialAccumulator();

  for (const ans of answers) {
    const q = qMap.get(ans.question_id);
    if (!q) continue;
    applySocialAnswer(accum, q, ans.answer_type, ans.answer_json);
  }

  const result: AxesScores = {};
  for (const axis of SOCIAL_AXIS_NAMES) {
    result[axis] = Math.max(0, Math.min(100, Math.round(50 + accum[axis].sum)));
  }
  return result;
}

function applySocialAnswer(
  accum: Record<string, AxisAccum>,
  q: DnkQuestion,
  answerType: string,
  answerJson: any
): void {
  if (answerType === "scale") {
    const value = answerJson?.value;
    if (typeof value !== "number") return;
    const delta = value - 3;
    for (const [axis, weight] of Object.entries(q.axis_weights)) {
      if (accum[axis] === undefined) continue;
      accum[axis].sum += delta * weight;
      accum[axis].count += 1;
    }
  } else if (answerType === "forced_choice" || answerType === "sjt") {
    const key = answerJson?.key;
    if (typeof key !== "string" || !q.options) return;
    const opt = q.options.find((o) => o.id === key);
    if (!opt) return;
    for (const [axis, weight] of Object.entries(opt.axis_weights)) {
      if (accum[axis] === undefined) continue;
      accum[axis].sum += weight;
      accum[axis].count += 1;
    }
  }
}

export function mergeSocialWithAdjustments(
  base: AxesScores,
  adjustments: Record<string, number>
): AxesScores {
  const result: AxesScores = { ...base };
  for (const axis of SOCIAL_AXIS_NAMES) {
    const delta = typeof adjustments[axis] === "number" ? adjustments[axis] : 0;
    const clamped = Math.max(-10, Math.min(10, delta));
    result[axis] = Math.max(0, Math.min(100, Math.round((result[axis] ?? 50) + clamped)));
  }
  return result;
}

// ─── Inconsistency scoring ───────────────────────────────────
// Pairs of opposing scale questions.
// Conflict if both answered >=4 (strong agree on opposites) → 1.0
// Conflict if both answered <=2 (strong disagree on both) → 0.6
const OPPOSING_PAIRS: [string, string][] = [
  ["q09_structure_planning", "q10_structure_flow"],
  ["q11_publicness_attention", "q12_publicness_privacy"],
  ["q13_conflict_direct", "q14_conflict_diplomacy"],
  ["q07_lyric_truth", "q08_lyric_technique"],
  ["q15_commercial_instinct", "q16_commercial_integrity"],
];

export function computeInconsistency(answers: AnswerRow[]): number {
  const ansMap = new Map<string, number>();
  for (const a of answers) {
    if (a.answer_type === "scale" && typeof a.answer_json?.value === "number") {
      ansMap.set(a.question_id, a.answer_json.value);
    }
  }

  let total = 0;
  let count = 0;

  for (const [qA, qB] of OPPOSING_PAIRS) {
    const vA = ansMap.get(qA);
    const vB = ansMap.get(qB);
    if (vA === undefined || vB === undefined) continue;

    count++;
    if (vA >= 4 && vB >= 4) {
      total += 1.0;
    } else if (vA <= 2 && vB <= 2) {
      total += 0.6;
    }
    // else 0 — no conflict
  }

  if (count === 0) return 0;
  return Math.max(0, Math.min(1, total / count));
}

// ─── Confidence scoring ──────────────────────────────────────
// overall = 0.92
//   - 0.40 * max(inconsistency, red_flags.inconsistency)
//   - 0.25 * red_flags.low_effort
//   - 0.20 * red_flags.social_desirability
//   - (duration_sec < 120 → -0.08, <180 → -0.10)
// clamp [0.30..0.95]
// by_axis = overall, but if inconsistency >= 0.6 penalize specific axes

interface ConfidenceInput {
  inconsistency: number;
  redFlags: ExtractFeatures["red_flags"];
  durationSec: number;
}

export interface FullConfidence {
  overall: number;
  by_axis: ConfidenceScores;
}

export function computeFullConfidence(input: ConfidenceInput): FullConfidence {
  const { inconsistency, redFlags, durationSec } = input;

  let overall = 0.92
    - 0.40 * Math.max(inconsistency, redFlags.inconsistency)
    - 0.25 * redFlags.low_effort
    - 0.20 * redFlags.social_desirability;

  if (durationSec > 0 && durationSec < 120) {
    overall -= 0.08;
  } else if (durationSec > 0 && durationSec < 180) {
    overall -= 0.10;
  }

  overall = clamp(overall, 0.30, 0.95);

  const byAxis: ConfidenceScores = {};
  for (const axis of AXIS_NAMES) {
    byAxis[axis] = overall;
  }

  if (inconsistency >= 0.6) {
    byAxis["structure"] = clamp(byAxis["structure"] - 0.12, 0.30, 0.95);
    byAxis["publicness"] = clamp(byAxis["publicness"] - 0.08, 0.30, 0.95);
    byAxis["conflict_style"] = clamp(byAxis["conflict_style"] - 0.08, 0.30, 0.95);
    byAxis["lyric_focus"] = clamp(byAxis["lyric_focus"] - 0.08, 0.30, 0.95);
    byAxis["commercial_focus"] = clamp(byAxis["commercial_focus"] - 0.08, 0.30, 0.95);
  }

  return { overall, by_axis: byAxis };
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, +v.toFixed(2)));
}

// ─── Followup evaluation helpers ─────────────────────────────

export function isAxisUncertain(
  accum: Record<string, AxisAccum>,
  axis: string
): boolean {
  return (accum[axis]?.count ?? 0) < 2;
}

export function hasAxisConflict(
  accum: Record<string, AxisAccum>,
  axes: string[]
): boolean {
  if (axes.length === 1) {
    const a = accum[axes[0]];
    if (!a || a.count < 2) return false;
    return Math.abs(a.sum) < 6;
  }

  if (axes.length >= 2) {
    const signs = axes.map((ax) => {
      const a = accum[ax];
      if (!a || a.count === 0) return 0;
      return a.sum > 0 ? 1 : a.sum < 0 ? -1 : 0;
    });
    const nonZero = signs.filter((s) => s !== 0);
    if (nonZero.length < 2) return false;
    return nonZero.some((s) => s > 0) && nonZero.some((s) => s < 0);
  }

  return false;
}
