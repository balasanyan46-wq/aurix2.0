/**
 * Shared CORS utility for all handler modules.
 */

export interface CorsEnv {
  ENV?: string;
  ALLOWED_ORIGINS?: string;
}

export function buildCorsHeaders(
  request: Request,
  env: CorsEnv,
): Record<string, string> {
  const reqOrigin = request.headers.get("Origin") ?? "";
  const isDev = String(env.ENV ?? "").toLowerCase() === "dev";
  const allowedRaw = String(env.ALLOWED_ORIGINS ?? "").trim();

  let allowOrigin: string;

  if (isDev || !allowedRaw) {
    allowOrigin = "*";
  } else {
    const allowed = allowedRaw
      .split(",")
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    allowOrigin =
      reqOrigin && allowed.includes(reqOrigin)
        ? reqOrigin
        : allowed[0] ?? "*";
  }

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "Content-Type, Authorization, X-AURIX-INTERNAL-KEY",
    "Access-Control-Max-Age": "86400",
    ...(allowOrigin !== "*" ? { Vary: "Origin" } : {}),
  };
}

export function corsOptionsResponse(
  request: Request,
  env: CorsEnv,
): Response {
  return new Response(null, {
    status: 204,
    headers: buildCorsHeaders(request, env),
  });
}
