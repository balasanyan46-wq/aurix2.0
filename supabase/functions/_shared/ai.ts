export async function callOpenAI(
  apiKey: string,
  systemPrompt: string,
  userPrompt: string,
  maxTokens = 3000
): Promise<object> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      max_tokens: maxTokens,
      temperature: 0.85,
      response_format: { type: "json_object" },
    }),
  });

  const data = (await res.json()) as any;
  if (!res.ok) throw new Error(data?.error?.message ?? `OpenAI error ${res.status}`);

  const raw = data?.choices?.[0]?.message?.content?.trim() ?? "{}";
  return JSON.parse(raw);
}

export async function callViaWorkerOrDirect(
  toolName: string,
  body: object,
  systemPrompt: string,
  userPrompt: string,
  maxTokens: number
): Promise<object> {
  const workerUrl = Deno.env.get("CF_WORKER_URL");
  const internalKey = Deno.env.get("AURIX_INTERNAL_KEY");

  if (workerUrl && internalKey) {
    try {
      const cfRes = await fetch(`${workerUrl}/v1/tools/${toolName}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-AURIX-INTERNAL-KEY": internalKey,
        },
        body: JSON.stringify(body),
      });
      const cfBody = await cfRes.json() as any;
      if (cfBody.ok && cfBody.data) {
        console.log(`[${toolName}] Worker OK`);
        return cfBody.data;
      }
      console.warn(`[${toolName}] Worker failed: ${cfBody.error ?? cfRes.status}, trying direct...`);
    } catch (e) {
      console.warn(`[${toolName}] Worker unreachable: ${e}, trying direct...`);
    }
  }

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) {
    throw new Error("AI generation unavailable: neither Cloudflare Worker nor OpenAI key configured");
  }
  return callOpenAI(openaiKey, systemPrompt, userPrompt, maxTokens);
}

export function artistBlock(profile: any): string {
  const p = profile ?? {};
  const parts: string[] = [];
  if (p.artist_name) parts.push(`Артист: ${p.artist_name}`);
  if (p.real_name && p.real_name !== p.artist_name) parts.push(`Настоящее имя: ${p.real_name}`);
  if (p.city) parts.push(`Город: ${p.city}`);
  if (p.bio) parts.push(`Био: ${p.bio}`);
  return parts.length > 0 ? parts.join("\n") : "Информация об артисте не заполнена";
}

export function releaseBlock(release: any): string {
  const r = release ?? {};
  const parts = [
    `Релиз: «${r.title ?? "—"}»`,
    `Исполнитель: ${r.artist ?? "—"}`,
    `Жанр: ${r.genre ?? "не указан"}`,
    `Тип: ${r.release_type ?? "single"}`,
  ];
  if (r.language) parts.push(`Язык: ${r.language}`);
  if (r.label) parts.push(`Лейбл: ${r.label}`);
  if (r.release_date) parts.push(`Дата релиза: ${r.release_date}`);
  if (r.explicit) parts.push("Explicit: да");
  return parts.join("\n");
}

export function tracksBlock(tracks: any[]): string {
  if (!tracks?.length) return "Треки: не добавлены";
  return "Треки:\n" + tracks.map((t: any, i: number) =>
    `  ${i + 1}. «${t.title || "Без названия"}»${t.isrc ? ` [ISRC: ${t.isrc}]` : ""}${t.version && t.version !== "original" ? ` (${t.version})` : ""}${t.explicit ? " [E]" : ""}`
  ).join("\n");
}

export function catalogBlock(catalog: any[]): string {
  if (!catalog?.length) return "";
  return "\nДругие релизы артиста:\n" + catalog.map((r: any) =>
    `  — «${r.title}» (${r.release_type}, ${r.genre || "?"}, статус: ${r.status})`
  ).join("\n");
}

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
