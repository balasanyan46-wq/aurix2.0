import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { callViaWorkerOrDirect, artistBlock, releaseBlock, tracksBlock, catalogBlock, corsHeaders, json } from "../_shared/ai.ts";

const SYSTEM = `Ты — персональный AI-стратег музыкального маркетинга сервиса Aurix.

ВАЖНО: Каждый ответ должен быть УНИКАЛЬНЫМ и ПЕРСОНАЛЬНЫМ для конкретного артиста.
Используй ВСЮ информацию: называй артиста по имени, учитывай город, каталог, жанр.

Ответ СТРОГО в JSON:
{
  "summary": "персональная стратегия",
  "positioning": {"one_liner": "...", "angle": "...", "audience": "..."},
  "risks": ["..."],
  "levers": ["..."],
  "content_angles": ["..."],
  "quick_wins_48h": ["..."],
  "weekly_focus": [{"week":1,"focus":"..."},{"week":2,"focus":"..."},{"week":3,"focus":"..."},{"week":4,"focus":"..."}],
  "days": [{"day":0,"title":"...","tasks":["..."],"outputs":["..."],"time_min":45}, ...],
  "checkpoints": [{"day":7,"kpi":["..."],"actions":["..."]},{"day":14,...},{"day":30,...}]
}
Давай КОНКРЕТНЫЕ названия площадок, реальные KPI. Каждый день уникальный. Пиши на русском.`;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ ok: false, error: "Unauthorized" }, 401);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
    if (authErr || !user) return json({ ok: false, error: "Unauthorized" }, 401);

    const { releaseId, inputs } = await req.json();
    if (!releaseId || !inputs) return json({ ok: false, error: "Missing releaseId or inputs" }, 400);

    const { data: release } = await supabase.from("releases")
      .select("owner_id, title, artist, genre, release_date, release_type, language, upc, label, explicit")
      .eq("id", releaseId).single();
    if (!release) return json({ ok: false, error: "Release not found" }, 404);
    if (release.owner_id !== user.id) return json({ ok: false, error: "Forbidden" }, 403);

    const { data: profile } = await supabase.from("profiles")
      .select("plan, artist_name, display_name, name, city, bio, gender")
      .eq("user_id", user.id).single();
    const plan = profile?.plan ?? "start";
    const isDemo = plan === "start";

    const { data: tracks } = await supabase.from("tracks")
      .select("title, isrc, version, explicit, track_number")
      .eq("release_id", releaseId).order("track_number");
    const { data: otherReleases } = await supabase.from("releases")
      .select("title, artist, genre, release_type, status")
      .eq("owner_id", user.id).neq("id", releaseId)
      .order("created_at", { ascending: false }).limit(10);

    const prof = {
      artist_name: profile?.artist_name ?? profile?.display_name ?? profile?.name ?? "",
      real_name: profile?.name ?? "",
      city: profile?.city ?? "",
      bio: profile?.bio ?? "",
      plan,
    };

    const i = inputs ?? {};
    const userPrompt = `=== ПРОФИЛЬ АРТИСТА ===\n${artistBlock(prof)}\n\n=== РЕЛИЗ ===\n${releaseBlock(release)}\n\n=== ТРЕКЛИСТ ===\n${tracksBlock(tracks ?? [])}\n${catalogBlock(otherReleases ?? [])}\n\n=== ПАРАМЕТРЫ ===\nЖанр: ${i.genre ?? release.genre ?? "не указан"}\nДата: ${i.releaseDate ?? release.release_date ?? "не указана"}\nЦель: ${i.goal ?? "streams"}\nРегион: ${i.region ?? "RU"}\nПлатформы: ${(i.platforms ?? ["spotify"]).join(", ")}\nАудитория: ${i.audience ?? "не указана"}\n\nСоздай ПЕРСОНАЛЬНУЮ 30-дневную карту роста.`;

    const workerBody = { release, inputs, profile: prof, tracks: tracks ?? [], catalog: otherReleases ?? [] };
    const output = await callViaWorkerOrDirect("growth-plan", workerBody, SYSTEM, userPrompt, 4000);

    await supabase.from("release_tools").upsert({
      user_id: user.id, release_id: releaseId, tool_key: "growth-plan",
      is_demo: isDemo, input: inputs, output,
    }, { onConflict: "user_id,release_id,tool_key" });

    return json({ ok: true, is_demo: isDemo, data: output });
  } catch (e) {
    console.error("[release-growth-plan]", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
