import {
  calculateAttentionIndex,
  classifyStatus,
  scoreToLabel,
  type AaiScorePayload,
} from "./scoring";
import {
  isSuspiciousUserAgent,
  isAnomalousBurst,
  isClickTooFrequent,
  hashIp,
} from "./bot_guard";

import { buildCorsHeaders } from "../cors";

export interface AaiEnv {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ENV?: string;
  ALLOWED_ORIGINS?: string;
}

type AnyObj = Record<string, unknown>;

let _jsonHeaders: Record<string, string> = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function setCorsForRequest(request: Request, env: AaiEnv): void {
  _jsonHeaders = { "Content-Type": "application/json", ...buildCorsHeaders(request, env) };
}

const oneHour = 3600;
const twoDaysMs = 48 * oneHour * 1000;

function jsonResp(body: AnyObj, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: _jsonHeaders });
}

function textResp(html: string, status = 200): Response {
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

function nowIso(): string {
  return new Date().toISOString();
}

function getCountry(request: Request): string | null {
  return request.headers.get("CF-IPCountry") || null;
}

function getReferrer(request: Request): string | null {
  return request.headers.get("referer") || null;
}

function getUserAgent(request: Request): string | null {
  return request.headers.get("user-agent") || null;
}

function getClientIp(request: Request): string | null {
  return request.headers.get("CF-Connecting-IP") || null;
}

function getCookieValue(cookieHeader: string | null, key: string): string | null {
  if (!cookieHeader) return null;
  const pairs = cookieHeader.split(";").map((x) => x.trim());
  for (const p of pairs) {
    if (!p.startsWith(`${key}=`)) continue;
    return decodeURIComponent(p.substring(key.length + 1));
  }
  return null;
}

function makeSessionId(): string {
  try {
    return crypto.randomUUID();
  } catch {
    return `aai_${Date.now()}_${Math.floor(Math.random() * 1e8)}`;
  }
}

async function supabaseFetch(
  env: AaiEnv,
  path: string,
  init: RequestInit = {}
): Promise<Response> {
  const headers = new Headers(init.headers ?? {});
  headers.set("apikey", env.SUPABASE_SERVICE_ROLE_KEY);
  headers.set("Authorization", `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`);
  if (!headers.has("Content-Type") && init.body) {
    headers.set("Content-Type", "application/json");
  }
  return fetch(`${env.SUPABASE_URL}/rest/v1/${path}`, { ...init, headers });
}

async function insertView(
  env: AaiEnv,
  payload: {
    releaseId: string;
    sessionId: string;
    country: string | null;
    referrer: string | null;
    userAgent: string | null;
    ipHash: string | null;
    eventType?: "view" | "leave";
    engagedSeconds?: number;
    isSuspicious?: boolean;
    isFiltered?: boolean;
  }
): Promise<void> {
  await supabaseFetch(env, "release_page_views", {
    method: "POST",
    body: JSON.stringify({
      release_id: payload.releaseId,
      session_id: payload.sessionId,
      country: payload.country,
      referrer: payload.referrer,
      user_agent: payload.userAgent,
      ip_hash: payload.ipHash,
      event_type: payload.eventType ?? "view",
      engaged_seconds: payload.engagedSeconds ?? 0,
      is_suspicious: payload.isSuspicious ?? false,
      is_filtered: payload.isFiltered ?? false,
      created_at: nowIso(),
    }),
  });
}

async function insertClick(
  env: AaiEnv,
  payload: {
    releaseId: string;
    platform: string;
    redirectUrl: string | null;
    sessionId: string;
    country: string | null;
    referrer: string | null;
    userAgent: string | null;
    ipHash: string | null;
    isSuspicious?: boolean;
    isFiltered?: boolean;
  }
): Promise<void> {
  await supabaseFetch(env, "release_clicks", {
    method: "POST",
    body: JSON.stringify({
      release_id: payload.releaseId,
      platform: payload.platform,
      redirect_url: payload.redirectUrl,
      session_id: payload.sessionId,
      country: payload.country,
      referrer: payload.referrer,
      user_agent: payload.userAgent,
      ip_hash: payload.ipHash,
      is_suspicious: payload.isSuspicious ?? false,
      is_filtered: payload.isFiltered ?? false,
      created_at: nowIso(),
    }),
  });
}

async function fetchReleaseMeta(
  env: AaiEnv,
  releaseId: string
): Promise<{ id: string; title: string; artist: string | null } | null> {
  const res = await supabaseFetch(
    env,
    `releases?select=id,title,artist&id=eq.${encodeURIComponent(releaseId)}&limit=1`
  );
  if (!res.ok) return null;
  const rows = (await res.json()) as Array<{ id: string; title: string; artist: string | null }>;
  return rows[0] ?? null;
}

async function fetchViews(
  env: AaiEnv,
  releaseId: string,
  sinceIso: string
): Promise<
  Array<{
    created_at: string;
    session_id: string;
    country: string | null;
    event_type: string;
    engaged_seconds: number;
    is_filtered: boolean;
  }>
> {
  const q =
    `release_page_views?select=created_at,session_id,country,event_type,engaged_seconds,is_filtered` +
    `&release_id=eq.${encodeURIComponent(releaseId)}&created_at=gte.${encodeURIComponent(sinceIso)}`;
  const res = await supabaseFetch(env, q);
  if (!res.ok) return [];
  return (await res.json()) as Array<{
    created_at: string;
    session_id: string;
    country: string | null;
    event_type: string;
    engaged_seconds: number;
    is_filtered: boolean;
  }>;
}

async function fetchClicks(
  env: AaiEnv,
  releaseId: string,
  sinceIso: string
): Promise<
  Array<{
    created_at: string;
    session_id: string;
    platform: string;
    country: string | null;
    is_filtered: boolean;
  }>
> {
  const q =
    `release_clicks?select=created_at,session_id,platform,country,is_filtered` +
    `&release_id=eq.${encodeURIComponent(releaseId)}&created_at=gte.${encodeURIComponent(sinceIso)}`;
  const res = await supabaseFetch(env, q);
  if (!res.ok) return [];
  return (await res.json()) as Array<{
    created_at: string;
    session_id: string;
    platform: string;
    country: string | null;
    is_filtered: boolean;
  }>;
}

async function upsertAaiIndex(env: AaiEnv, releaseId: string, score: AaiScorePayload): Promise<void> {
  await supabaseFetch(env, "release_attention_index?on_conflict=release_id", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify({
      release_id: releaseId,
      impulse_score: score.impulseScore,
      conversion_score: score.conversionScore,
      engagement_score: score.engagementScore,
      geography_score: score.geographyScore,
      total_score: score.totalScore,
      status_code: classifyStatus(score.totalScore),
      score_prev: score.scorePrev,
      delta_24h: score.delta24h,
      delta_48h: score.delta48h,
      views_48h: score.views48h,
      clicks_48h: score.clicks48h,
      unique_countries_48h: score.uniqueCountries48h,
      updated_at: nowIso(),
    }),
  });
}

async function recalcAndPersist(env: AaiEnv, releaseId: string): Promise<void> {
  const since = new Date(Date.now() - twoDaysMs).toISOString();
  const viewsRaw = await fetchViews(env, releaseId, since);
  const clicksRaw = await fetchClicks(env, releaseId, since);
  const views = viewsRaw.filter((v) => !v.is_filtered);
  const clicks = clicksRaw.filter((c) => !c.is_filtered);
  const score = calculateAttentionIndex({ views, clicks });
  await upsertAaiIndex(env, releaseId, score);
}

function platformTarget(platform: string, artist: string, title: string): string {
  const q = encodeURIComponent(`${artist} ${title}`.trim());
  switch (platform) {
    case "spotify":
      return `https://open.spotify.com/search/${q}`;
    case "apple":
      return `https://music.apple.com/search?term=${q}`;
    case "yandex":
      return `https://music.yandex.ru/search?text=${q}`;
    case "youtube":
      return `https://music.youtube.com/search?q=${q}`;
    default:
      return `https://www.google.com/search?q=${q}`;
  }
}

export async function handleSmartLink(
  request: Request,
  env: AaiEnv,
  releaseId: string
): Promise<Response> {
  setCorsForRequest(request, env);
  const release = await fetchReleaseMeta(env, releaseId);
  if (!release) return textResp("<h1>Release not found</h1>", 404);

  const cookieHeader = request.headers.get("cookie");
  const existingSid = getCookieValue(cookieHeader, "aai_sid");
  const sessionId = existingSid ?? makeSessionId();
  const userAgent = getUserAgent(request);
  const suspiciousUa = isSuspiciousUserAgent(userAgent);
  const ipHash = await hashIp(getClientIp(request));
  const burst = await isAnomalousBurst(env, releaseId, sessionId);
  const filtered = suspiciousUa || burst;

  await insertView(env, {
    releaseId,
    sessionId,
    country: getCountry(request),
    referrer: getReferrer(request),
    userAgent,
    ipHash,
    eventType: "view",
    isSuspicious: suspiciousUa || burst,
    isFiltered: filtered,
  });
  await recalcAndPersist(env, releaseId);

  const artist = release.artist ?? "Unknown Artist";
  const links = [
    { platform: "spotify", url: platformTarget("spotify", artist, release.title), label: "Spotify" },
    { platform: "apple", url: platformTarget("apple", artist, release.title), label: "Apple Music" },
    { platform: "yandex", url: platformTarget("yandex", artist, release.title), label: "Яндекс Музыка" },
    { platform: "youtube", url: platformTarget("youtube", artist, release.title), label: "YouTube Music" },
  ];
  const linksHtml = links
    .map(
      (l) => `<a class="btn" href="/aai/click?release_id=${encodeURIComponent(
        releaseId
      )}&platform=${encodeURIComponent(l.platform)}&to=${encodeURIComponent(l.url)}">${l.label}</a>`
    )
    .join("");

  const html = `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${release.title} · AURIX</title>
<style>
body{margin:0;background:#07080b;color:#f5f5f5;font-family:Inter,system-ui,sans-serif}
.wrap{max-width:540px;margin:0 auto;padding:24px}
.card{background:#11131a;border:1px solid #232633;border-radius:16px;padding:18px}
.title{font-size:26px;font-weight:800;margin:0 0 4px}
.artist{color:#9ea3b8;margin-bottom:14px}
.grid{display:grid;gap:10px}
.btn{display:block;padding:12px 14px;background:#ff8f00;color:#111;text-decoration:none;border-radius:10px;font-weight:700;text-align:center}
.hint{font-size:12px;color:#7f8498;margin-top:14px}
</style></head>
<body><div class="wrap"><div class="card">
<div class="title">${release.title}</div>
<div class="artist">${artist}</div>
<div class="grid">${linksHtml}</div>
<div class="hint">Powered by AURIX Attention Index</div>
</div></div>
<script>
const sid="${sessionId}";
const releaseId="${releaseId}";
window.addEventListener("pagehide", () => {
  const ts=Math.round(performance.now()/1000);
  navigator.sendBeacon("/aai/visit", new Blob([JSON.stringify({
    release_id: releaseId, session_id: sid, event_type: "leave", engaged_seconds: ts
  })], {type:"application/json"}));
});
</script>
</body></html>`;

  const res = textResp(html);
  if (!existingSid) {
    res.headers.append(
      "Set-Cookie",
      `aai_sid=${encodeURIComponent(sessionId)}; Path=/; Max-Age=${60 * 60 * 24 * 30}; HttpOnly; Secure; SameSite=Lax`
    );
  }
  return res;
}

export async function handleVisit(request: Request, env: AaiEnv): Promise<Response> {
  setCorsForRequest(request, env);
  if (request.method !== "POST") return jsonResp({ error: "Method not allowed" }, 405);
  let body: AnyObj;
  try {
    body = (await request.json()) as AnyObj;
  } catch {
    return jsonResp({ error: "Invalid JSON" }, 400);
  }
  const releaseId = String(body.release_id ?? "").trim();
  if (!releaseId) return jsonResp({ error: "release_id required" }, 400);
  const sessionId =
    String(body.session_id ?? "").trim() ||
    getCookieValue(request.headers.get("cookie"), "aai_sid") ||
    makeSessionId();
  const userAgent = getUserAgent(request);
  const suspiciousUa = isSuspiciousUserAgent(userAgent);
  const ipHash = await hashIp(getClientIp(request));
  const eventType = body.event_type === "leave" ? "leave" : "view";
  const engagedSeconds = Number(body.engaged_seconds ?? 0) || 0;
  const filtered = suspiciousUa;

  await insertView(env, {
    releaseId,
    sessionId,
    country: getCountry(request),
    referrer: getReferrer(request),
    userAgent,
    ipHash,
    eventType,
    engagedSeconds: engagedSeconds > 0 ? engagedSeconds : 0,
    isSuspicious: suspiciousUa,
    isFiltered: filtered,
  });
  await recalcAndPersist(env, releaseId);

  return jsonResp({ ok: true, session_id: sessionId });
}

export async function handleClick(request: Request, env: AaiEnv): Promise<Response> {
  setCorsForRequest(request, env);
  const url = new URL(request.url);
  const releaseId = String(url.searchParams.get("release_id") ?? "").trim();
  const platform = String(url.searchParams.get("platform") ?? "").trim().toLowerCase();
  const redirectTo = String(url.searchParams.get("to") ?? "").trim();
  const body =
    request.method === "POST" ? (((await request.json().catch(() => ({}))) as AnyObj) ?? {}) : {};

  const releaseFromBody = String(body.release_id ?? "").trim();
  const platformFromBody = String(body.platform ?? "").trim().toLowerCase();
  const toFromBody = String(body.to ?? "").trim();

  const rid = releaseId || releaseFromBody;
  const plt = platform || platformFromBody;
  const target = redirectTo || toFromBody;
  if (!rid || !plt) return jsonResp({ error: "release_id and platform required" }, 400);

  const sessionId =
    String(body.session_id ?? "").trim() ||
    getCookieValue(request.headers.get("cookie"), "aai_sid") ||
    makeSessionId();
  const userAgent = getUserAgent(request);
  const suspiciousUa = isSuspiciousUserAgent(userAgent);
  const ipHash = await hashIp(getClientIp(request));
  const tooFast = await isClickTooFrequent(env, rid, sessionId, plt, 5);
  const burst = await isAnomalousBurst(env, rid, sessionId);
  const filtered = suspiciousUa || tooFast || burst;

  await insertClick(env, {
    releaseId: rid,
    platform: plt,
    redirectUrl: target || null,
    sessionId,
    country: getCountry(request),
    referrer: getReferrer(request),
    userAgent,
    ipHash,
    isSuspicious: suspiciousUa || tooFast || burst,
    isFiltered: filtered,
  });
  await recalcAndPersist(env, rid);

  if (request.method === "GET" && target) {
    return Response.redirect(target, 302);
  }
  return jsonResp({ ok: true, filtered, session_id: sessionId });
}

export async function handleTop10(request: Request, env: AaiEnv): Promise<Response> {
  setCorsForRequest(request, env);
  const q = `release_attention_index?select=release_id,total_score,status_code,updated_at&order=total_score.desc&limit=10`;
  const idxRes = await supabaseFetch(env, q);
  if (!idxRes.ok) return jsonResp({ error: "Failed to read AAI index" }, 502);
  const rows = (await idxRes.json()) as Array<{
    release_id: string;
    total_score: number;
    status_code: string;
    updated_at: string;
  }>;

  const ids = rows.map((r) => r.release_id).filter(Boolean);
  const idCsv = ids.map((id) => `"${id}"`).join(",");
  const metaRes =
    ids.length > 0
      ? await supabaseFetch(
          env,
          `releases?select=id,title,artist,cover_url&id=in.(${encodeURIComponent(idCsv)})`
        )
      : null;
  const metas = metaRes && metaRes.ok ? ((await metaRes.json()) as AnyObj[]) : [];
  const byId = new Map<string, AnyObj>(metas.map((m) => [String(m.id), m]));

  const top = rows.map((r) => {
    const m = byId.get(r.release_id);
    const score = Number(r.total_score ?? 0);
    return {
      release_id: r.release_id,
      title: String(m?.title ?? "Unknown release"),
      artist: String(m?.artist ?? "Unknown artist"),
      cover_url: (m?.cover_url as string | null) ?? null,
      total_score: score,
      status_code: r.status_code,
      status_label: scoreToLabel(score),
      updated_at: r.updated_at,
    };
  });
  return jsonResp({ top });
}

export async function handleTopPage(request: Request, env: AaiEnv): Promise<Response> {
  setCorsForRequest(request, env);
  const dataResp = await handleTop10(request, env);
  const data = (await dataResp.json()) as { top?: Array<AnyObj> };
  const top = data.top ?? [];

  const rows = top
    .map((x, i) => {
      const score = Number(x.total_score ?? 0).toFixed(1);
      return `<li class="row"><span class="num">${i + 1}</span><span class="meta"><b>${x.title}</b><small>${x.artist}</small></span><span class="score">${score}</span><span class="badge">${x.status_label}</span></li>`;
    })
    .join("");

  return textResp(`<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AURIX AAI Top-10</title>
<style>
body{margin:0;background:#07080b;color:#f6f7fb;font-family:Inter,system-ui,sans-serif}
.wrap{max-width:760px;margin:0 auto;padding:24px}
.card{background:#11131a;border:1px solid #232633;border-radius:16px;padding:18px}
h1{margin:0 0 6px;font-size:28px}
.sub{color:#8f94ab;margin-bottom:14px}
ul{list-style:none;padding:0;margin:0;display:grid;gap:10px}
.row{display:grid;grid-template-columns:36px 1fr auto auto;gap:10px;align-items:center;background:#171a23;border:1px solid #252a38;border-radius:12px;padding:10px}
.num{color:#ff8f00;font-weight:800}
.meta{display:flex;flex-direction:column}
.meta small{color:#9da3b7}
.score{font-weight:800}
.badge{font-size:12px;color:#ff8f00}
</style></head><body><div class="wrap"><div class="card">
<h1>AURIX Attention Index</h1><div class="sub">Топ-10 релизов по интересу аудитории</div>
<ul>${rows || "<li>Пока нет данных</li>"}</ul>
</div></div></body></html>`);
}

