import type { AaiEnv } from "./handlers";

const suspiciousUaPattern =
  /(bot|crawler|spider|headless|phantom|selenium|python|curl|wget|postman|insomnia)/i;

function toMs(iso: string): number {
  return new Date(iso).getTime();
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

export function isSuspiciousUserAgent(userAgent: string | null): boolean {
  if (!userAgent || !userAgent.trim()) return true;
  return suspiciousUaPattern.test(userAgent);
}

export async function hashIp(ip: string | null): Promise<string | null> {
  if (!ip) return null;
  const encoded = new TextEncoder().encode(ip);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function isClickTooFrequent(
  env: AaiEnv,
  releaseId: string,
  sessionId: string,
  platform: string,
  minSeconds: number
): Promise<boolean> {
  const q =
    `release_clicks?select=created_at&release_id=eq.${encodeURIComponent(releaseId)}` +
    `&session_id=eq.${encodeURIComponent(sessionId)}&platform=eq.${encodeURIComponent(platform)}` +
    `&order=created_at.desc&limit=1`;
  const res = await supabaseFetch(env, q);
  if (!res.ok) return false;
  const rows = (await res.json()) as Array<{ created_at: string }>;
  if (!rows[0]) return false;
  const diffMs = Date.now() - toMs(rows[0].created_at);
  return diffMs < minSeconds * 1000;
}

export async function isAnomalousBurst(
  env: AaiEnv,
  releaseId: string,
  sessionId: string
): Promise<boolean> {
  const since = new Date(Date.now() - 60_000).toISOString();
  const q =
    `release_page_views?select=id&release_id=eq.${encodeURIComponent(releaseId)}` +
    `&session_id=eq.${encodeURIComponent(sessionId)}&created_at=gte.${encodeURIComponent(since)}`;
  const res = await supabaseFetch(env, q);
  if (!res.ok) return false;
  const rows = (await res.json()) as Array<{ id: string }>;
  return rows.length > 30;
}

