import type { AxisAccum, TestQuestion } from "./types";

interface AnswerRow {
  question_id: string;
  answer_type: string;
  answer_json: any;
}

export function buildAccumulator(axes: string[]): Record<string, AxisAccum> {
  const out: Record<string, AxisAccum> = {};
  for (const a of axes) out[a] = { sum: 0, count: 0, max_abs: 0 };
  return out;
}

export function applyAnswer(
  accum: Record<string, AxisAccum>,
  q: TestQuestion,
  answerType: string,
  answerJson: any
): void {
  if (answerType === "scale") {
    const value = answerJson?.value;
    if (typeof value !== "number") return;
    const delta = value - 3;
    for (const [axis, weight] of Object.entries(q.axis_weights)) {
      if (!accum[axis]) continue;
      accum[axis].sum += delta * weight;
      accum[axis].count += 1;
      accum[axis].max_abs += Math.abs(weight) * 2;
    }
    return;
  }

  if (answerType === "forced_choice" || answerType === "sjt") {
    const key = answerJson?.key;
    if (!q.options || typeof key !== "string") return;
    const opt = q.options.find((x) => x.id === key);
    if (!opt) return;
    const perAxisMax = new Map<string, number>();
    for (const candidate of q.options) {
      for (const [axis, w] of Object.entries(candidate.axis_weights)) {
        perAxisMax.set(axis, Math.max(perAxisMax.get(axis) ?? 0, Math.abs(w)));
      }
    }
    for (const [axis, weight] of Object.entries(opt.axis_weights)) {
      if (!accum[axis]) continue;
      accum[axis].sum += weight;
      accum[axis].count += 1;
      accum[axis].max_abs += perAxisMax.get(axis) ?? Math.abs(weight);
    }
  }
}

export function scoreFromAccum(accum: Record<string, AxisAccum>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const [axis, a] of Object.entries(accum)) {
    const maxAbs = Math.max(1, a.max_abs);
    const normalized = a.sum / maxAbs;
    out[axis] = clamp(Math.round(50 + normalized * 50), 0, 100);
  }
  return out;
}

export function mergeAdjustments(
  base: Record<string, number>,
  adjustments: Record<string, number>
): Record<string, number> {
  const out: Record<string, number> = { ...base };
  for (const axis of Object.keys(base)) {
    const d = typeof adjustments[axis] === "number" ? adjustments[axis] : 0;
    out[axis] = clamp(Math.round((out[axis] ?? 50) + clamp(d, -12, 12)), 0, 100);
  }
  return out;
}

export function computeInconsistency(
  answers: AnswerRow[],
  qMap: Map<string, TestQuestion>,
  axes: string[]
): number {
  const accum = buildAccumulator(axes);
  for (const a of answers) {
    const q = qMap.get(a.question_id);
    if (!q) continue;
    applyAnswer(accum, q, a.answer_type, a.answer_json);
  }
  const unstable = Object.values(accum).filter((a) => a.count > 0 && Math.abs(a.sum) < Math.max(1, a.max_abs * 0.12)).length;
  return clamp(unstable / Math.max(1, axes.length), 0, 1);
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}
