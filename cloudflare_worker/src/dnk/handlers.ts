import type { DnkEnv } from "./types";
import { AXIS_NAMES } from "./types";
import { DNK_CORE_QUESTIONS, getFollowupById, getAllQuestionsMap } from "./questions";
import {
  buildAccumulator,
  applyAnswer,
  computeBaseAxes,
  computeSocialBaseAxes,
  mergeWithAdjustments,
  mergeSocialWithAdjustments,
  computeInconsistency,
  computeFullConfidence,
  isAxisUncertain,
  hasAxisConflict,
} from "./scoring";
import { createLLMProvider } from "./llm";
import { callLLMWithAutoRepair, EXTRACT_FEATURES_HINT, GENERATE_PROFILE_HINT } from "./llm_repair";
import { ExtractFeaturesSchema, GenerateProfileSchema } from "./schemas";
import { EXTRACT_FEATURES_SYSTEM, GENERATE_PROFILE_SYSTEM, GENERATE_PROFILE_FAST_SYSTEM } from "./prompts";

// ── Answer type mapping (UI ↔ DB) ──────────────────────────
// UI/question bank uses: scale, forced_choice, sjt, open
// DB CHECK constraint allows: scale, choice, sjt, open_text
const UI_TO_DB: Record<string, string> = {
  scale: "scale",
  forced_choice: "choice",
  choice: "choice",
  sjt: "sjt",
  open: "open_text",
  open_text: "open_text",
};

const DB_TO_UI: Record<string, string> = {
  scale: "scale",
  choice: "forced_choice",
  sjt: "sjt",
  open_text: "open",
};

function toDbAnswerType(uiType: string): string {
  const mapped = UI_TO_DB[uiType];
  if (!mapped) throw new Error(`Unknown DNK answer type: ${uiType}`);
  return mapped;
}

function toUiAnswerType(dbType: string): string {
  return DB_TO_UI[dbType] ?? dbType;
}

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-AURIX-INTERNAL-KEY",
  "Access-Control-Max-Age": "86400",
};

function json(body: object, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

// ── Supabase helper ─────────────────────────────────────────
function validateEnv(env: DnkEnv): void {
  if (!env.SUPABASE_URL || !env.SUPABASE_URL.startsWith("https://")) {
    throw new Error("Misconfigured: SUPABASE_URL must be https:// URL");
  }
  if (!env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_SERVICE_ROLE_KEY.startsWith("https://")) {
    throw new Error("Misconfigured: SUPABASE_SERVICE_ROLE_KEY is empty or looks like URL");
  }
  if (!env.SUPABASE_SERVICE_ROLE_KEY.startsWith("eyJ")) {
    throw new Error("Misconfigured: SUPABASE_SERVICE_ROLE_KEY must be a JWT (eyJ...)");
  }
}

async function sbQuery(
  env: DnkEnv,
  path: string,
  opts: { method?: string; body?: any; headers?: Record<string, string> } = {}
): Promise<any> {
  validateEnv(env);
  const url = `${env.SUPABASE_URL}/rest/v1/${path}`;
  const res = await fetch(url, {
    method: opts.method ?? "GET",
    headers: {
      "Content-Type": "application/json",
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      Prefer: opts.method === "POST" ? "return=representation" : "return=minimal",
      ...opts.headers,
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase ${res.status}: ${text}`);
  }

  const ct = res.headers.get("content-type") ?? "";
  if (ct.includes("json")) return res.json();
  return null;
}

// ── POST /dnk/start ─────────────────────────────────────────
export async function handleDnkStart(request: Request, env: DnkEnv): Promise<Response> {
  let body: any;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const userId = body.user_id;
  if (!userId) return json({ error: "user_id required" }, 400);

  try {
    const rows = await sbQuery(env, "dnk_sessions", {
      method: "POST",
      body: { user_id: userId, status: "in_progress", version: 1 },
    });

    const sessionId = rows?.[0]?.id;
    if (!sessionId) throw new Error("No session id returned");

    return json({
      session_id: sessionId,
      questions: DNK_CORE_QUESTIONS,
    });
  } catch (e: any) {
    return json({ error: e.message ?? "Failed to create session" }, 500);
  }
}

// ── POST /dnk/answer ────────────────────────────────────────
export async function handleDnkAnswer(request: Request, env: DnkEnv): Promise<Response> {
  const t0 = Date.now();
  let body: any;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const { session_id, question_id, answer_type, answer_json } = body;
  if (!session_id || !question_id || !answer_type) {
    return json({ error: "session_id, question_id, answer_type required" }, 400);
  }

  try {
    const dbType = toDbAnswerType(answer_type);

    await sbQuery(env, "dnk_answers?on_conflict=session_id,question_id", {
      method: "POST",
      body: {
        session_id,
        question_id,
        answer_type: dbType,
        answer_json: answer_json ?? {},
      },
      headers: { Prefer: "return=minimal,resolution=merge-duplicates" },
    });

    const qMap = getAllQuestionsMap();
    const currentQ = qMap.get(question_id);
    let followup: any = null;

    // IDK detection for q36/q37 open-text social questions
    if (
      (question_id === "q36_open_attract" || question_id === "q37_open_repel") &&
      answer_json
    ) {
      const text = ((answer_json as any).text ?? "").toString().trim().toLowerCase();
      const IDK_PATTERNS = ["не знаю", "не уверен", "хз", "без понятия", "затрудняюсь", "не могу"];
      const isIdk = text.length < 4 || IDK_PATTERNS.some((p) => text.includes(p));
      if (isIdk) {
        const hintId = question_id === "q36_open_attract" ? "f06_attract_hint" : "f07_repel_hint";
        const hintQ = getFollowupById(hintId);
        if (hintQ) followup = hintQ;
      }
    }

    if (!followup && currentQ?.followup_rules && currentQ.followup_rules.length > 0) {
      const allAnswers: any[] = await sbQuery(
        env,
        `dnk_answers?session_id=eq.${session_id}&order=created_at.asc`
      );

      const accum = buildAccumulator();
      for (const ans of allAnswers) {
        const q = qMap.get(ans.question_id);
        if (!q) continue;
        applyAnswer(accum, q, toUiAnswerType(ans.answer_type), ans.answer_json);
      }

      const answeredIds = new Set(allAnswers.map((a: any) => a.question_id));

      for (const rule of currentQ.followup_rules) {
        let triggered = false;
        if (rule.if_axis_uncertain) {
          triggered = isAxisUncertain(accum, rule.if_axis_uncertain);
        } else if (rule.if_axis_conflict) {
          triggered = hasAxisConflict(accum, rule.if_axis_conflict);
        }

        if (triggered) {
          for (const fid of rule.ask) {
            if (!answeredIds.has(fid)) {
              const fq = getFollowupById(fid);
              if (fq) { followup = fq; break; }
            }
          }
        }
        if (followup) break;
      }
    }

    console.log(`[DNK] /answer q=${question_id} ms=${Date.now() - t0}`);
    return json({ ok: true, followup });
  } catch (e: any) {
    console.error(`[DNK] /answer error q=${question_id} ms=${Date.now() - t0}: ${e.message}`);
    return json({ error: e.message ?? "Failed to store answer" }, 500);
  }
}

// ── POST /dnk/finish — synchronous generation, returns full result ──
export async function handleDnkFinish(
  request: Request,
  env: DnkEnv,
  _ctx: ExecutionContext
): Promise<Response> {
  const t0 = Date.now();
  let body: any;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const sessionId = body.session_id;
  const styleLevel: string = body.style_level === "hard" ? "hard" : "normal";
  if (!sessionId) return json({ error: "session_id required" }, 400);

  try {
    const probe: any[] = await sbQuery(
      env,
      `dnk_answers?session_id=eq.${sessionId}&select=id&limit=1`
    );
    if (!probe || probe.length === 0) {
      return json({ ok: false, error: "No answers found for session" }, 400);
    }

    console.log(`[DNK] finish start session=${sessionId} style=${styleLevel}`);

    const result = await doGenerateProfile(env, sessionId, styleLevel, t0);

    console.log(`[DNK] finish done session=${sessionId} ms=${Date.now() - t0}`);
    return json({ ok: true, status: "ready", ...result });
  } catch (e: any) {
    const msg = e.message ?? String(e);
    console.error(`[DNK /finish] Error: ${msg}`);
    if (msg === "LLM_NOT_CONFIGURED") {
      return json({ ok: false, code: "LLM_NOT_CONFIGURED", message: "Missing OpenAI API key" }, 500);
    }
    return json({ ok: false, status: "failed", error: msg }, 500);
  }
}

// ── Synchronous profile generation ──────────────────────────
async function doGenerateProfile(
  env: DnkEnv,
  sessionId: string,
  styleLevel: string,
  t0: number
): Promise<Record<string, any>> {
    const answers: any[] = await sbQuery(
      env,
      `dnk_answers?session_id=eq.${sessionId}&order=created_at.asc`
    );
    if (!answers || answers.length === 0) throw new Error("No answers found");
    console.log(`[DNK] generate session=${sessionId} answers=${answers.length}`);

    const uiAnswers = answers.map((a: any) => ({
      ...a,
      answer_type: toUiAnswerType(a.answer_type),
    }));

    const axesBase = computeBaseAxes(uiAnswers);
    const socialAxesBase = computeSocialBaseAxes(uiAnswers);

    const qMap = getAllQuestionsMap();
    const structuredAnswers = uiAnswers.map((a: any) => {
      const q = qMap.get(a.question_id);
      let answer: any;
      if (a.answer_type === "scale") {
        answer = a.answer_json?.value;
      } else if (a.answer_type === "forced_choice" || a.answer_type === "sjt") {
        const key = a.answer_json?.key;
        const opt = q?.options?.find((o: any) => o.id === key);
        answer = { key, label: opt?.label ?? key };
      } else {
        answer = a.answer_json?.text ?? "";
      }
      return { question_id: a.question_id, type: a.answer_type, answer };
    });

    const sessions: any[] = await sbQuery(
      env,
      `dnk_sessions?id=eq.${sessionId}&select=id,locale,version,started_at`
    );
    const session = sessions?.[0] ?? { id: sessionId, locale: "ru", version: 1 };
    const durationSec = session.started_at
      ? Math.round((Date.now() - new Date(session.started_at).getTime()) / 1000)
      : 0;

    const llm = createLLMProvider(env);
    let llmUsed = true;

    const extractPayload = JSON.stringify({
      session: { id: sessionId, locale: session.locale ?? "ru", version: session.version ?? 1 },
      answers: structuredAnswers,
      axes_base: axesBase,
      social_axes_base: socialAxesBase,
      meta: { duration_sec: durationSec },
    });

    const EXTRACT_TIMEOUT = 25_000;
    const GENERATE_TIMEOUT = 60_000;

    let features: any;
    try {
      console.log(`[DNK] extract_features start timeout_ms=${EXTRACT_TIMEOUT}`);
      const extractResult = await callLLMWithAutoRepair({
        provider: llm,
        systemPrompt: EXTRACT_FEATURES_SYSTEM,
        userPayload: extractPayload,
        schema: ExtractFeaturesSchema,
        schemaHint: EXTRACT_FEATURES_HINT,
        maxRetries: 1,
        llmOpts: { timeoutMs: EXTRACT_TIMEOUT, maxTokens: 2000 },
      });
      features = extractResult.data;
      console.log(`[DNK] extract_features ok repaired=${extractResult.repaired} attempts=${extractResult.attempts} ms=${Date.now() - t0}`);
    } catch (e: any) {
      console.error(`[DNK] extract_features failed, using fallback: ${e.message ?? e}`);
      llmUsed = false;
      features = {
        tags: [],
        axis_adjustments: { energy: 0, novelty: 0, darkness: 0, lyric_focus: 0, structure: 0, conflict_style: 0, publicness: 0, commercial_focus: 0 },
        social_adjustments: { warmth: 0, power: 0, edge: 0, clarity: 0 },
        red_flags: { social_desirability: 0, low_effort: 0, inconsistency: 0 },
        notes: "LLM недоступен — базовый профиль",
      };
    }

    const axesFinal = mergeWithAdjustments(axesBase, features.axis_adjustments);
    const socialAxesFinal = mergeSocialWithAdjustments(
      socialAxesBase,
      features.social_adjustments ?? {}
    );

    const inconsistency = computeInconsistency(uiAnswers);
    const confidence = computeFullConfidence({
      inconsistency,
      redFlags: features.red_flags,
      durationSec,
    });

    const identityAnswer = structuredAnswers.find((a: any) => a.question_id === "q24_open_identity");
    const nonnegotiableAnswer = structuredAnswers.find((a: any) => a.question_id === "q25_open_nonnegotiable");
    const attractAnswer = structuredAnswers.find((a: any) => a.question_id === "q36_open_attract");
    const repelAnswer = structuredAnswers.find((a: any) => a.question_id === "q37_open_repel");

    const profileMode = "fast";
    const profilePrompt = profileMode === "fast" ? GENERATE_PROFILE_FAST_SYSTEM : GENERATE_PROFILE_SYSTEM;
    const profileMaxTokens = profileMode === "fast" ? 3000 : 4000;

    console.log(`[DNK] generate_profile start mode=${profileMode} style=${styleLevel} timeout_ms=${GENERATE_TIMEOUT}`);

    const profilePayload = JSON.stringify({
      session: { id: sessionId, locale: session.locale ?? "ru", version: session.version ?? 1 },
      style_level: styleLevel,
      axes_final: axesFinal,
      social_axes_final: socialAxesFinal,
      confidence,
      tags: features.tags,
      open_text: {
        identity_line: identityAnswer?.answer ?? "",
        nonnegotiable: nonnegotiableAnswer?.answer ?? "",
        attract: attractAnswer?.answer ?? "",
        repel: repelAnswer?.answer ?? "",
      },
    });

    let profile: any;
    try {
      const profileResult = await callLLMWithAutoRepair({
        provider: llm,
        systemPrompt: profilePrompt,
        userPayload: profilePayload,
        schema: GenerateProfileSchema,
        schemaHint: GENERATE_PROFILE_HINT,
        maxRetries: 0,
        llmOpts: { timeoutMs: GENERATE_TIMEOUT, maxTokens: profileMaxTokens },
      });
      profile = postProcessProfile(profileResult.data);
      console.log(`[DNK] generate_profile ok mode=${profileMode} repaired=${profileResult.repaired} attempts=${profileResult.attempts} ms=${Date.now() - t0}`);
    } catch (e: any) {
      console.error(`[DNK] generate_profile timeout -> fallback: ${e.message ?? e}`);
      llmUsed = false;
      profile = buildFallbackProfile();
    }

    const profileText = `${profile.profile_short}\n\n${profile.profile_full}`;

    const existingResults: any[] = await sbQuery(
      env,
      `dnk_results?session_id=eq.${sessionId}&select=id`
    );
    const regenCount = existingResults?.length ?? 0;

    const resultRows = await sbQuery(env, "dnk_results", {
      method: "POST",
      body: {
        session_id: sessionId,
        axes: axesFinal,
        confidence: confidence.by_axis,
        profile_text: profileText,
        recommendations: {
          ...profile.recommendations,
          social_summary: profile.social_summary,
          passport_hero: profile.passport_hero,
          _profile_short: profile.profile_short,
          _profile_full: profile.profile_full,
          _social_axes: socialAxesFinal,
          _meta: { status: "ready", llm_used: llmUsed },
        },
        prompts: profile.prompts,
        raw_features: features,
        regen_count: regenCount,
      },
    });

    await sbQuery(env, `dnk_sessions?id=eq.${sessionId}`, {
      method: "PATCH",
      body: { status: "finished", finished_at: new Date().toISOString() },
      headers: { Prefer: "return=minimal" },
    });

    return {
      result_id: resultRows?.[0]?.id,
      axes: axesFinal,
      social_axes: socialAxesFinal,
      confidence,
      profile_text: profileText,
      profile_short: profile.profile_short,
      profile_full: profile.profile_full,
      passport_hero: profile.passport_hero,
      recommendations: profile.recommendations,
      prompts: profile.prompts,
      social_summary: profile.social_summary,
      tags: features.tags,
      red_flags: features.red_flags,
      inconsistency,
      regen_count: regenCount,
      llm_used: llmUsed,
    };
}

// ── Post-process LLM output: clean text, enforce quality ─────
function postProcessProfile(p: any): any {
  const clean = (s: string) =>
    s.replace(/\s{2,}/g, " ").replace(/\n{3,}/g, "\n\n").trim();
  const cleanArr = (arr: any) =>
    Array.isArray(arr) ? arr.map((s: any) => clean(String(s))) : arr;

  if (p.passport_hero) {
    const h = p.passport_hero;
    h.hook = clean(h.hook ?? "");
    h.how_people_feel_you = clean(h.how_people_feel_you ?? "");
    h.shadow = clean(h.shadow ?? "");
    h.magnet = cleanArr(h.magnet);
    h.repulsion = cleanArr(h.repulsion);
    h.taboo = cleanArr(h.taboo);
    h.next_7_days = cleanArr(h.next_7_days);

    if (Array.isArray(h.taboo)) {
      h.taboo = h.taboo.map((t: string) =>
        t.startsWith("Нельзя:") ? t : `Нельзя: ${t}`
      );
    }
  }

  if (p.social_summary) {
    const ss = p.social_summary;
    ss.magnets = cleanArr(ss.magnets);
    ss.repellers = cleanArr(ss.repellers);
    ss.people_come_for = clean(ss.people_come_for ?? "");
    ss.people_leave_when = clean(ss.people_leave_when ?? "");
    ss.taboos = cleanArr(ss.taboos);
    if (Array.isArray(ss.taboos)) {
      ss.taboos = ss.taboos.map((t: string) =>
        t.startsWith("Нельзя:") ? t : `Нельзя: ${t}`
      );
    }
  }

  p.profile_short = clean(p.profile_short ?? "");
  p.profile_full = clean(p.profile_full ?? "");

  return p;
}

// ── Fallback profile when LLM is unavailable ────────────────
function buildFallbackProfile(): any {
  return {
    profile_short: "Базовый профиль сгенерирован. Перегенерируйте для полного AI-анализа.",
    profile_full: "AI-анализ был недоступен. Нажмите «Перегенерировать» для полного профиля.",
    passport_hero: {
      hook: "Твой профиль собран — перегенерируй для полной версии.",
      how_people_feel_you: "",
      magnet: [],
      repulsion: [],
      shadow: "",
      taboo: [],
      next_7_days: ["Перегенерируй профиль для полного результата"],
    },
    recommendations: {
      music: { genres: [], tempo_range_bpm: [90, 140], mood: [], lyrics: [], do: [], avoid: [] },
      content: { platform_focus: [], content_pillars: [], posting_rhythm: "", hooks: [], do: [], avoid: [] },
      behavior: { teamwork: [], conflict_style: "", public_replies: [], stress_protocol: [] },
      visual: { palette: [], materials: [], references: [], wardrobe: [], do: [], avoid: [] },
    },
    prompts: { track_concept: "", lyrics_seed: "", cover_prompt: "", reels_series: "" },
    social_summary: {
      magnets: ["—", "—", "—"],
      repellers: ["—", "—", "—"],
      people_come_for: "—",
      people_leave_when: "—",
      taboos: ["—", "—", "—", "—", "—"],
      scripts: {
        hate_reply: ["—", "—"],
        interview_style: ["—"],
        conflict_style: ["—"],
        teamwork_rule: ["—"],
      },
    },
  };
}

// ── GET /dnk/result — poll by result_id (or session_id fallback) ────────────
export async function handleDnkGetResult(request: Request, env: DnkEnv): Promise<Response> {
  const t0 = Date.now();
  const url = new URL(request.url);
  const resultId = url.searchParams.get("result_id");
  const sessionId = url.searchParams.get("session_id");

  if (!resultId && !sessionId) {
    return json({ ok: false, error: "result_id or session_id required" }, 400);
  }

  try {
    const query = resultId
      ? `dnk_results?id=eq.${resultId}&limit=1`
      : `dnk_results?session_id=eq.${sessionId}&order=created_at.desc&limit=1`;

    const rows: any[] = await sbQuery(env, query);
    if (!rows || rows.length === 0) {
      return json({ ok: true, status: "processing" });
    }

    const r = rows[0];
    const recs = r.recommendations ?? {};
    const meta = recs._meta ?? {};
    const genStatus: string = meta.status ?? "processing";

    if (genStatus === "processing") {
      return json({ ok: true, status: "processing" });
    }

    if (genStatus === "failed") {
      console.log(`[DNK] /result failed result_id=${r.id} ms=${Date.now() - t0}`);
      return json({
        ok: false,
        status: "failed",
        error_code: meta.error_code ?? "UNKNOWN",
        error_message: meta.error_message ?? "Генерация не удалась",
      });
    }

    const rawFeatures = r.raw_features ?? {};

    const data = {
      result_id: r.id,
      axes: r.axes ?? {},
      social_axes: r.social_axes ?? recs._social_axes ?? {},
      confidence: r.confidence ?? {},
      profile_text: r.profile_text ?? "",
      profile_short: recs._profile_short ?? "",
      profile_full: recs._profile_full ?? r.profile_text ?? "",
      passport_hero: recs.passport_hero ?? {},
      recommendations: {
        music: recs.music ?? {},
        content: recs.content ?? {},
        behavior: recs.behavior ?? {},
        visual: recs.visual ?? {},
      },
      prompts: r.prompts ?? {},
      social_summary: recs.social_summary ?? {},
      tags: rawFeatures.tags ?? [],
      red_flags: rawFeatures.red_flags ?? {},
      inconsistency: 0,
      regen_count: r.regen_count ?? 0,
      llm_used: meta.llm_used ?? true,
    };

    console.log(`[DNK] /result ready result_id=${r.id} ms=${Date.now() - t0}`);
    return json({ ok: true, status: "ready", ...data });
  } catch (e: any) {
    console.error(`[DNK /result] Error: ${e.message ?? e}`);
    return json({ ok: false, error: "Failed to check result" }, 500);
  }
}

export function handleDnkOptions(): Response {
  return new Response(null, { status: 204, headers: corsHeaders });
}
