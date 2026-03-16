import { callLLMWithAutoRepair } from "../dnk/llm_repair";
import { createLLMProvider } from "../dnk/llm";
import { DNK_TEST_CATALOG, getTestDef } from "./catalog";
import { getAllQuestionsMap, getCoreQuestions, getFollowupById, getQuestionById } from "./questions";
import { buildAccumulator, applyAnswer, computeInconsistency, mergeAdjustments, scoreFromAccum } from "./scoring";
import { EXTRACT_TEST_FEATURES_HINT, ExtractTestFeaturesSchema, TestResultSchema, TEST_RESULT_HINT } from "./schemas";
import { EXTRACT_TEST_FEATURES_SYSTEM, resultSystemPrompt } from "./prompts";
import type { DnkTestsEnv, DnkTestSlug } from "./types";

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

import { buildCorsHeaders } from "../cors";

let _corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-AURIX-INTERNAL-KEY",
  "Access-Control-Max-Age": "86400",
};

function setCorsForRequest(request: Request, env: DnkTestsEnv): void {
  _corsHeaders = buildCorsHeaders(request, env);
}

function json(body: object, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ..._corsHeaders },
  });
}

function toDbAnswerType(uiType: string): string {
  const mapped = UI_TO_DB[uiType];
  if (!mapped) throw new Error(`Unknown answer type: ${uiType}`);
  return mapped;
}

function toUiAnswerType(dbType: string): string {
  return DB_TO_UI[dbType] ?? dbType;
}

function normText(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-zа-я0-9\s]/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function dedupeTextList(items: string[], max = 10): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of items) {
    const v = String(raw ?? "").trim();
    if (!v) continue;
    const n = normText(v);
    if (!n || seen.has(n)) continue;
    seen.add(n);
    out.push(v);
    if (out.length >= max) break;
  }
  return out;
}

function fallbackPromptsBySlug(slug: DnkTestSlug): string[] {
  switch (slug) {
    case "artist_archetype":
      return [
        "Собери 3 визуальные сцены твоего архетипа: тишина, напряжение, взрыв.",
        "Напиши подпись к фото как манифест сценического образа в 2 строках.",
        "Сгенерируй сценарий Reels: герой входит в кадр и ломает ожидание аудитории.",
        "Создай 5 hooks для поста, где уязвимость звучит как сила.",
        "Собери moodboard: цвет, свет, фактура, символ, который повторяется в клипах.",
        "Напиши интро к треку, где главный конфликт образа проговаривается прямо.",
      ];
    case "tone_communication":
      return [
        "Напиши 10 коротких фраз для сторис в моем тоне: прямота + теплота без оправданий.",
        "Сгенерируй 7 вариантов CTA для прогрева релиза без давления на аудиторию.",
        "Дай 8 hooks для Reels в моем стиле речи: резко, ясно, без канцелярита.",
        "Перепиши этот текст в моем голосе: меньше воды, больше смысла и ритма.",
        "Сделай 6 подписей к посту в тоне 'честно и по делу', до 12 слов каждая.",
        "Собери словарь: 20 слов-опор и 20 слов-табу для моего контента.",
      ];
    case "story_core":
      return [
        "Дай 5 сюжетных линий песни вокруг конфликта 'контроль vs близость'.",
        "Сгенерируй 8 образов для куплета: город, ночь, выбор, цена решения.",
        "Напиши структуру клипа из 6 сцен, где герой меняет позицию к финалу.",
        "Собери 10 строк-переходов между уязвимостью и силой без клише.",
        "Придумай 5 концовок истории: открытая, жесткая, примиряющая, холодная, дерзкая.",
        "Сделай 7 концептов Reels, где каждая сцена раскрывает внутренний конфликт.",
      ];
    case "growth_profile":
      return [
        "Составь план роста на 7 дней для канала комьюнити: действия и метрика по каждому дню.",
        "Придумай 6 UGC-механик для трека, чтобы аудитория сама снимала контент.",
        "Напиши сценарий live-эфира на 20 минут с вовлекающими точками каждые 3 минуты.",
        "Собери 10 идей коллабов под мой жанр и текущую стадию релиза.",
        "Дай 8 постов для прогрева релиза: от интриги до явного call-to-action.",
        "Определи 5 анти-стратегий, которые крадут охваты, и чем их заменить.",
      ];
    case "discipline_index":
      return [
        "Собери утренний ритуал на 25 минут для входа в фокус и старта работы.",
        "Дай 7 анти-срыв правил: что делать в первые 10 минут после потери ритма.",
        "Напиши рабочий регламент на неделю: студия, контент, отдых, контроль прогресса.",
        "Сгенерируй 10 коротких self-commands для возврата в дисциплину без самокритики.",
        "Придумай вечерний чек-аут: 5 вопросов для фикса результата дня.",
        "Собери систему защиты фокуса при хаотичном графике и внешнем шуме.",
      ];
    case "career_risk":
      return [
        "Опиши 5 признаков моего самосаботажа и быстрый ответ на каждый.",
        "Сделай антикризисный сценарий на 72 часа, когда я начинаю откладывать релиз.",
        "Напиши 8 фраз-переключателей из режима избегания в режим действия.",
        "Собери план выхода из перфекционистской петли: минимум шагов, максимум эффекта.",
        "Сгенерируй 6 постов про честный прогресс без образа идеальности.",
        "Дай 7 микро-решений, которые снижают зависимость от чужого одобрения.",
      ];
  }
}

function isGenericPrompt(s: string): boolean {
  const n = normText(s);
  return [
    "давайте обсудим это более подробно",
    "как вы считаете",
    "есть ли у вас вопросы",
    "могу предложить альтернативный подход",
    "какое ваше мнение по этому вопросу",
  ].some((x) => n.includes(x));
}

async function sbQuery(
  env: DnkTestsEnv,
  path: string,
  opts: { method?: string; body?: any; headers?: Record<string, string> } = {}
): Promise<any> {
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

function serializeQuestion(q: any) {
  return {
    id: q.id,
    type: q.type,
    text: q.text,
    test_slug: q.test_slug,
    scale_labels: q.scale?.labels ?? null,
    options: q.options?.map((x: any) => ({ key: x.id, text: x.label })) ?? null,
    is_followup: q.id.includes("_f"),
  };
}

export function handleDnkTestsOptions(request?: Request, env?: DnkTestsEnv): Response {
  const headers = request && env ? buildCorsHeaders(request, env) : _corsHeaders;
  return new Response(null, { status: 204, headers });
}

export async function handleDnkTestsCatalog(_request: Request, env: DnkTestsEnv): Promise<Response> {
  setCorsForRequest(_request, env);
  try {
    const rows: any[] = await sbQuery(
      env,
      "dnk_test_defs?select=slug,title_ru,description,example_json,is_active,sort_order&is_active=eq.true&order=sort_order.asc"
    );
    if (rows && rows.length > 0) {
      return json({
        tests: rows.map((r) => ({
          slug: r.slug,
          title: r.title_ru,
          description: r.description,
          what_gives: DNK_TEST_CATALOG.find((x) => x.slug === r.slug)?.whatGives ?? "",
          example_result: DNK_TEST_CATALOG.find((x) => x.slug === r.slug)?.exampleResult ?? "",
          example_json: r.example_json ?? {},
        })),
      });
    }
  } catch {
    // fallback to static catalog
  }

  return json({
    tests: DNK_TEST_CATALOG.map((t) => ({
      slug: t.slug,
      title: t.title,
      description: t.description,
      what_gives: t.whatGives,
      example_result: t.exampleResult,
      example_json: {},
    })),
  });
}

export async function handleDnkTestsProgress(request: Request, env: DnkTestsEnv): Promise<Response> {
  setCorsForRequest(request, env);
  const url = new URL(request.url);
  const userId = (url.searchParams.get("user_id") ?? "").trim();
  if (!userId) return json({ error: "user_id required" }, 400);

  try {
    const sessions: any[] = await sbQuery(
      env,
      `dnk_test_sessions?user_id=eq.${userId}&status=eq.finished&select=id,test_slug,finished_at,created_at&order=created_at.desc&limit=200`
    );
    if (!sessions || sessions.length === 0) {
      return json({ progress: [] });
    }

    const latestSessionBySlug = new Map<string, any>();
    for (const s of sessions) {
      if (!s?.test_slug) continue;
      if (!latestSessionBySlug.has(s.test_slug)) latestSessionBySlug.set(s.test_slug, s);
    }

    const progress: any[] = [];
    for (const [testSlug, session] of latestSessionBySlug.entries()) {
      const rows: any[] = await sbQuery(
        env,
        `dnk_test_results?session_id=eq.${session.id}&select=id,created_at&order=created_at.desc&limit=1`
      );
      const latestResult = rows?.[0];
      progress.push({
        test_slug: testSlug,
        completed: true,
        session_id: session.id,
        result_id: latestResult?.id ?? null,
        completed_at: session.finished_at ?? session.created_at ?? latestResult?.created_at ?? null,
      });
    }

    return json({ progress });
  } catch (e: any) {
    return json({ error: e.message ?? "Failed to load tests progress" }, 500);
  }
}

export async function handleDnkTestsStart(request: Request, env: DnkTestsEnv): Promise<Response> {
  setCorsForRequest(request, env);
  let body: any;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const userId = body.user_id?.toString();
  const testSlug = body.test_slug?.toString() as DnkTestSlug | undefined;
  if (!userId || !testSlug) return json({ error: "user_id and test_slug required" }, 400);
  const testDef = getTestDef(testSlug);
  if (!testDef) return json({ error: "Unknown test_slug" }, 400);

  try {
    const rows = await sbQuery(env, "dnk_test_sessions", {
      method: "POST",
      body: { user_id: userId, test_slug: testSlug, status: "in_progress", version: 1 },
    });
    const sessionId = rows?.[0]?.id;
    if (!sessionId) throw new Error("No session id");
    const questions = getCoreQuestions(testSlug).map(serializeQuestion);
    return json({ session_id: sessionId, test_slug: testSlug, questions });
  } catch (e: any) {
    return json({ error: e.message ?? "Failed to create test session" }, 500);
  }
}

export async function handleDnkTestsAnswer(request: Request, env: DnkTestsEnv): Promise<Response> {
  setCorsForRequest(request, env);
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
    await sbQuery(env, "dnk_test_answers?on_conflict=session_id,question_id", {
      method: "POST",
      body: {
        session_id,
        question_id,
        answer_type: toDbAnswerType(answer_type),
        answer_json: answer_json ?? {},
      },
      headers: { Prefer: "return=minimal,resolution=merge-duplicates" },
    });

    const currentQ = getQuestionById(question_id);
    let followup: any = null;
    if (currentQ?.followup_rules && currentQ.followup_rules.length > 0) {
      const allAnswers: any[] = await sbQuery(
        env,
        `dnk_test_answers?session_id=eq.${session_id}&select=question_id,answer_type,answer_json&order=created_at.asc`
      );

      const sessionRows: any[] = await sbQuery(env, `dnk_test_sessions?id=eq.${session_id}&select=test_slug`);
      const testSlug = sessionRows?.[0]?.test_slug as DnkTestSlug | undefined;
      const def = testSlug ? getTestDef(testSlug) : undefined;
      const axes = def?.axes ?? [];

      const qMap = getAllQuestionsMap();
      const accum = buildAccumulator(axes);
      for (const a of allAnswers) {
        const q = qMap.get(a.question_id);
        if (!q) continue;
        applyAnswer(accum, q, toUiAnswerType(a.answer_type), a.answer_json);
      }

      const answeredIds = new Set(allAnswers.map((a: any) => a.question_id));
      for (const rule of currentQ.followup_rules) {
        let triggered = false;
        if (rule.if_axis_uncertain) {
          const axis = accum[rule.if_axis_uncertain];
          if (axis) {
            const maxAbs = Math.max(1, axis.max_abs);
            triggered = Math.abs(axis.sum) / maxAbs < 0.18;
          }
        } else if (rule.if_axis_conflict && rule.if_axis_conflict.length > 0) {
          const xs = rule.if_axis_conflict.map((k) => accum[k]).filter(Boolean);
          triggered = xs.length > 1 && xs.every((x) => Math.abs(x.sum) / Math.max(1, x.max_abs) < 0.24);
        }
        if (triggered) {
          for (const id of rule.ask) {
            if (answeredIds.has(id)) continue;
            const fq = getFollowupById(id);
            if (fq) {
              followup = serializeQuestion(fq);
              break;
            }
          }
        }
        if (followup) break;
      }
    }

    return json({ ok: true, followup });
  } catch (e: any) {
    return json({ error: e.message ?? "Failed to save answer" }, 500);
  }
}

export async function handleDnkTestsFinish(request: Request, env: DnkTestsEnv): Promise<Response> {
  setCorsForRequest(request, env);
  let body: any;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }
  const sessionId = body.session_id?.toString();
  if (!sessionId) return json({ error: "session_id required" }, 400);

  try {
    const sessionRows: any[] = await sbQuery(
      env,
      `dnk_test_sessions?id=eq.${sessionId}&select=id,test_slug,user_id,started_at`
    );
    const session = sessionRows?.[0];
    if (!session) return json({ error: "Session not found" }, 404);
    const testSlug = session.test_slug as DnkTestSlug;
    const def = getTestDef(testSlug);
    if (!def) return json({ error: "Unknown test slug in session" }, 500);

    const answers: any[] = await sbQuery(
      env,
      `dnk_test_answers?session_id=eq.${sessionId}&select=question_id,answer_type,answer_json&order=created_at.asc`
    );
    if (!answers || answers.length === 0) return json({ error: "No answers for session" }, 400);

    const qMap = getAllQuestionsMap();
    const accum = buildAccumulator(def.axes);
    for (const a of answers) {
      const q = qMap.get(a.question_id);
      if (!q) continue;
      applyAnswer(accum, q, toUiAnswerType(a.answer_type), a.answer_json);
    }
    const baseAxes = scoreFromAccum(accum);
    const inconsistency = computeInconsistency(
      answers.map((a) => ({ ...a, answer_type: toUiAnswerType(a.answer_type) })),
      qMap,
      def.axes
    );

    const startedAt = session.started_at ? new Date(session.started_at).getTime() : Date.now();
    const durationSec = Math.max(1, Math.round((Date.now() - startedAt) / 1000));
    const openAnswers = answers
      .filter((a) => toUiAnswerType(a.answer_type) === "open")
      .map((a) => String(a.answer_json?.text ?? "").trim())
      .filter(Boolean);
    const lowEffortSeed =
      openAnswers.length === 0
        ? 0.6
        : Math.max(0, Math.min(1, 1 - openAnswers.join(" ").length / 180));

    const llm = createLLMProvider(env as any);
    const extractPayload = JSON.stringify({
      test_slug: testSlug,
      test_title: def.title,
      axes: def.axes,
      answers: answers.map((a) => ({
        question_id: a.question_id,
        answer_type: toUiAnswerType(a.answer_type),
        answer_json: a.answer_json,
      })),
      base_axes: baseAxes,
      duration_sec: durationSec,
      heuristics: { inconsistency, low_effort_seed: Number(lowEffortSeed.toFixed(3)) },
    });

    const featuresResult = await callLLMWithAutoRepair({
      provider: llm as any,
      systemPrompt: EXTRACT_TEST_FEATURES_SYSTEM,
      userPayload: extractPayload,
      schema: ExtractTestFeaturesSchema,
      schemaHint: EXTRACT_TEST_FEATURES_HINT,
      maxRetries: 1,
      llmOpts: { timeoutMs: 30_000, maxTokens: 1500 },
    });

    const features = featuresResult.data;
    const axisAdjustments: Record<string, number> = {};
    for (const axis of def.axes) axisAdjustments[axis] = features.axis_adjustments?.[axis] ?? 0;
    const finalAxes = mergeAdjustments(baseAxes, axisAdjustments);

    const resultPayloadInput = JSON.stringify({
      test_slug: testSlug,
      test_title: def.title,
      score_axes: finalAxes,
      tags: features.tags,
      notes: features.notes,
      constraints: {
        summary: "3-6 предложений",
        strengths: "4-7",
        risks: "4-7",
        actions_7_days: "ровно 7 пунктов",
        content_prompts: "6-10 пунктов",
      },
    });

    const resultGen = await callLLMWithAutoRepair({
      provider: llm as any,
      systemPrompt: resultSystemPrompt(testSlug),
      userPayload: resultPayloadInput,
      schema: TestResultSchema,
      schemaHint: TEST_RESULT_HINT,
      maxRetries: 1,
      llmOpts: { timeoutMs: 45_000, maxTokens: 2200 },
    });
    const resultData = resultGen.data;
    resultData.score_axes = finalAxes;
    resultData.strengths = dedupeTextList(resultData.strengths, 7);
    resultData.risks = dedupeTextList(resultData.risks, 7);
    resultData.actions_7_days = dedupeTextList(resultData.actions_7_days, 7);
    resultData.content_prompts = dedupeTextList(
      resultData.content_prompts.filter((x: string) => !isGenericPrompt(x)),
      10
    );
    if (resultData.content_prompts.length < 6) {
      const fallback = dedupeTextList(fallbackPromptsBySlug(testSlug), 10);
      const merged = dedupeTextList([...resultData.content_prompts, ...fallback], 10);
      resultData.content_prompts = merged.slice(0, Math.max(6, merged.length));
    }

    const existingRows: any[] = await sbQuery(
      env,
      `dnk_test_results?session_id=eq.${sessionId}&select=id`
    );
    const regenCount = existingRows?.length ?? 0;

    const insertRows = await sbQuery(env, "dnk_test_results", {
      method: "POST",
      body: {
        session_id: sessionId,
        test_slug: testSlug,
        score_axes: resultData.score_axes,
        summary: resultData.summary,
        strengths: resultData.strengths,
        risks: resultData.risks,
        actions_7_days: resultData.actions_7_days,
        content_prompts: resultData.content_prompts,
        payload: resultData,
        confidence: {
          inconsistency,
          overall: Number((0.9 - inconsistency * 0.3 - lowEffortSeed * 0.2).toFixed(3)),
        },
        raw_features: features,
        regen_count: regenCount,
      },
    });

    await sbQuery(env, `dnk_test_sessions?id=eq.${sessionId}`, {
      method: "PATCH",
      body: { status: "finished", finished_at: new Date().toISOString() },
      headers: { Prefer: "return=minimal" },
    });

    const resultId = insertRows?.[0]?.id;
    return json({
      ok: true,
      status: "ready",
      result_id: resultId,
      session_id: sessionId,
      test_slug: testSlug,
      ...resultData,
    });
  } catch (e: any) {
    return json({ ok: false, error: e.message ?? "Failed to finish test" }, 500);
  }
}

export async function handleDnkTestsGetResult(request: Request, env: DnkTestsEnv): Promise<Response> {
  setCorsForRequest(request, env);
  const url = new URL(request.url);
  const resultId = url.searchParams.get("result_id");
  const sessionId = url.searchParams.get("session_id");
  if (!resultId && !sessionId) {
    return json({ ok: false, error: "result_id or session_id required" }, 400);
  }
  try {
    const query = resultId
      ? `dnk_test_results?id=eq.${resultId}&select=*&limit=1`
      : `dnk_test_results?session_id=eq.${sessionId}&select=*&order=created_at.desc&limit=1`;
    const rows: any[] = await sbQuery(env, query);
    if (!rows || rows.length === 0) {
      return json({ ok: true, status: "processing" });
    }
    const r = rows[0];
    return json({
      ok: true,
      status: "ready",
      result_id: r.id,
      session_id: r.session_id,
      test_slug: r.test_slug,
      score_axes: r.score_axes ?? {},
      summary: r.summary ?? "",
      strengths: r.strengths ?? [],
      risks: r.risks ?? [],
      actions_7_days: r.actions_7_days ?? [],
      content_prompts: r.content_prompts ?? [],
      payload: r.payload ?? {},
      confidence: r.confidence ?? {},
      regen_count: r.regen_count ?? 0,
      created_at: r.created_at,
    });
  } catch (e: any) {
    return json({ ok: false, error: e.message ?? "Failed to get result" }, 500);
  }
}
