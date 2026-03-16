type ViewEvent = {
  created_at: string;
  session_id: string;
  country: string | null;
  event_type: string;
  engaged_seconds: number;
};

type ClickEvent = {
  created_at: string;
  session_id: string;
  platform: string;
  country: string | null;
};

export type AaiScorePayload = {
  impulseScore: number;
  conversionScore: number;
  engagementScore: number;
  geographyScore: number;
  totalScore: number;
  scorePrev: number;
  delta24h: number;
  delta48h: number;
  views48h: number;
  clicks48h: number;
  uniqueCountries48h: number;
};

export function classifyStatus(score: number): "hot" | "accelerating" | "watching" | "quiet" {
  if (score >= 80) return "hot";
  if (score >= 60) return "accelerating";
  if (score >= 40) return "watching";
  return "quiet";
}

export function scoreToLabel(score: number): string {
  if (score >= 80) return "Горящий";
  if (score >= 60) return "Разгоняется";
  if (score >= 40) return "Наблюдают";
  return "Тихий";
}

function clamp(v: number, min = 0, max = 100): number {
  return Math.max(min, Math.min(max, v));
}

function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

function toMs(iso: string): number {
  return new Date(iso).getTime();
}

export function calculateAttentionIndex(input: {
  views: ViewEvent[];
  clicks: ClickEvent[];
  nowMs?: number;
}): AaiScorePayload {
  const nowMs = input.nowMs ?? Date.now();
  const t24 = nowMs - 24 * 3600 * 1000;
  const t48 = nowMs - 48 * 3600 * 1000;

  const views = input.views.filter((v) => toMs(v.created_at) >= t48);
  const clicks = input.clicks.filter((c) => toMs(c.created_at) >= t48);

  const views48 = views.length;
  const clicks48 = clicks.length;

  const clicksLast24 = clicks.filter((c) => toMs(c.created_at) >= t24).length;
  const clicksPrev24 = clicks48 - clicksLast24;

  // 1) Impulse 40%: absolute activity + growth speed
  const activityScore = clamp((clicks48 / 180) * 100);
  const growthRatio = (clicksLast24 - clicksPrev24) / Math.max(clicksPrev24, 1);
  const growthScore = clamp((growthRatio + 1) * 50); // -100% =>0, 0%=>50, +100%=>100
  const impulseScore = round2(activityScore * 0.65 + growthScore * 0.35);

  // 2) Conversion 25%: clicks / page views
  const conversion = views48 > 0 ? clicks48 / views48 : 0;
  const conversionScore = round2(clamp((conversion / 0.35) * 100));

  // 3) Engagement 20%: repeat visits + dwell approx
  const sessions = new Map<string, number>();
  for (const v of views) sessions.set(v.session_id, (sessions.get(v.session_id) ?? 0) + 1);
  const uniqueSessions = sessions.size;
  const repeatSessions = [...sessions.values()].filter((n) => n > 1).length;
  const repeatRatio = uniqueSessions > 0 ? repeatSessions / uniqueSessions : 0;
  const repeatScore = clamp(repeatRatio * 100);

  const leaveEvents = views.filter((v) => v.event_type === "leave" && v.engaged_seconds > 0);
  const avgEngaged =
    leaveEvents.length > 0
      ? leaveEvents.reduce((sum, v) => sum + v.engaged_seconds, 0) / leaveEvents.length
      : 0;
  const dwellScore = clamp((avgEngaged / 120) * 100);
  const engagementScore = round2(repeatScore * 0.55 + dwellScore * 0.45);

  // 4) Geography 15%: diversity + distribution balance
  const countryCounts = new Map<string, number>();
  for (const v of views) {
    const c = (v.country ?? "").trim();
    if (!c) continue;
    countryCounts.set(c, (countryCounts.get(c) ?? 0) + 1);
  }
  const uniqueCountries = countryCounts.size;
  const diversityScore = clamp((uniqueCountries / 10) * 100);
  const totalGeo = [...countryCounts.values()].reduce((a, b) => a + b, 0);
  let hhi = 0;
  if (totalGeo > 0) {
    for (const cnt of countryCounts.values()) {
      const p = cnt / totalGeo;
      hhi += p * p;
    }
  }
  const balanceScore = totalGeo > 0 ? clamp((1 - hhi) * 130) : 0;
  const geographyScore = round2(diversityScore * 0.6 + balanceScore * 0.4);

  const totalScore = round2(
    impulseScore * 0.4 +
      conversionScore * 0.25 +
      engagementScore * 0.2 +
      geographyScore * 0.15
  );

  // Approx score_prev based on previous 24h vs last 24h activity.
  const prevActivity = clamp((clicksPrev24 / 180) * 100);
  const scorePrev = round2(
    (prevActivity * 0.4) +
      (conversionScore * 0.25) +
      (engagementScore * 0.2) +
      (geographyScore * 0.15)
  );

  return {
    impulseScore,
    conversionScore,
    engagementScore,
    geographyScore,
    totalScore,
    scorePrev,
    delta24h: round2(totalScore - scorePrev),
    delta48h: round2(totalScore - scorePrev),
    views48h: views48,
    clicks48h: clicks48,
    uniqueCountries48h: uniqueCountries,
  };
}

