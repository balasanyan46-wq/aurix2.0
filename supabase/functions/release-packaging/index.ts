import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { callViaWorkerOrDirect, artistBlock, releaseBlock, tracksBlock, corsHeaders, json } from "../_shared/ai.ts";

const SYSTEM = `Ты — AI-копирайтер и маркетолог Aurix. Создаёшь УНИКАЛЬНУЮ упаковку для релиза.
Каждое описание, хук и CTA привязаны к настроению/содержанию трека и имени артиста.

Ответ СТРОГО в JSON:
{
  "title_variants": ["...", ... до 5],
  "description_platforms": {"yandex": "...", "vk": "...", "spotify": "...", "apple": "..."},
  "storytelling": "атмосферная зарисовка 3-5 предложений",
  "hooks": ["...", ... 10-15],
  "cta_variants": ["...", ... 5-10]
}
Хуки цепляющие без клише. EN-описания на английском. Пиши на русском (кроме EN-платформ).`;

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
      .select("owner_id, title, artist, genre, release_type, release_date, language, label, explicit")
      .eq("id", releaseId).single();
    if (!release) return json({ ok: false, error: "Release not found" }, 404);
    if (release.owner_id !== user.id) return json({ ok: false, error: "Forbidden" }, 403);

    const { data: sub } = await supabase.from("subscriptions")
      .select("plan")
      .eq("user_id", user.id).maybeSingle();

    const { data: profile } = await supabase.from("profiles")
      .select("plan, artist_name, display_name, name, city, bio")
      .eq("user_id", user.id).single();

    const plan = sub?.plan ?? profile?.plan ?? "start";
    const isDemo = plan === "start";

    const { data: tracks } = await supabase.from("tracks")
      .select("title, isrc, version, explicit, track_number")
      .eq("release_id", releaseId).order("track_number");

    const prof = {
      artist_name: profile?.artist_name ?? profile?.display_name ?? profile?.name ?? "",
      city: profile?.city ?? "", bio: profile?.bio ?? "", plan,
    };

    const i = inputs ?? {};
    const userPrompt = `=== ПРОФИЛЬ АРТИСТА ===\n${artistBlock(prof)}\n\n=== РЕЛИЗ ===\n${releaseBlock(release)}\n\n=== ТРЕКЛИСТ ===\n${tracksBlock(tracks ?? [])}\n\n=== ПАРАМЕТРЫ ===\nЖанр: ${i.genre ?? release.genre ?? "не указан"}\nВайб: ${i.vibe ?? "не указан"}\nО чём трек: ${i.about ?? "не указано"}\nРеференсы: ${i.references ?? "нет"}\nРегион: ${i.region ?? "RU"}\nПлатформы: ${(i.platforms ?? ["spotify", "yandex"]).join(", ")}\n\nСоздай УНИКАЛЬНУЮ упаковку для этого релиза.`;

    const workerBody = { release, inputs, profile: prof, tracks: tracks ?? [] };
    const output = await callViaWorkerOrDirect("release-packaging", workerBody, SYSTEM, userPrompt, 3000);

    await supabase.from("release_tools").upsert({
      user_id: user.id, release_id: releaseId, tool_key: "release-packaging",
      is_demo: isDemo, input: inputs, output,
    }, { onConflict: "user_id,release_id,tool_key" });

    return json({ ok: true, is_demo: isDemo, data: output });
  } catch (e) {
    console.error("[release-packaging]", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
