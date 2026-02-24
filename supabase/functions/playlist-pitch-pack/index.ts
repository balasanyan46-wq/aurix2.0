import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { callViaWorkerOrDirect, artistBlock, releaseBlock, tracksBlock, catalogBlock, corsHeaders, json } from "../_shared/ai.ts";

const SYSTEM = `Ты — AI-PR стратег Aurix. Создаёшь питч-пакет для плейлист-кураторов и журналистов.
Питч ПЕРСОНАЛЬНЫЙ от лица конкретного артиста.

Ответ СТРОГО в JSON:
{
  "short_pitch": "2-3 предложения на АНГЛИЙСКОМ для международных кураторов",
  "long_pitch": "5-8 предложений на РУССКОМ для СНГ-кураторов",
  "email_subjects": ["...", ... до 5],
  "press_lines": ["...", ... 5-8],
  "artist_bio": "профессиональная биография 3-5 предложений"
}
Short pitch на английском. Long pitch на русском. Без клише.`;

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
    const { data: otherReleases } = await supabase.from("releases")
      .select("title, artist, genre, release_type, status")
      .eq("owner_id", user.id).neq("id", releaseId)
      .order("created_at", { ascending: false }).limit(10);

    const prof = {
      artist_name: profile?.artist_name ?? profile?.display_name ?? profile?.name ?? "",
      real_name: profile?.name ?? "",
      city: profile?.city ?? "", bio: profile?.bio ?? "", plan,
    };

    const i = inputs ?? {};
    const userPrompt = `=== ПРОФИЛЬ АРТИСТА ===\n${artistBlock(prof)}\n\n=== РЕЛИЗ ===\n${releaseBlock(release)}\n\n=== ТРЕКЛИСТ ===\n${tracksBlock(tracks ?? [])}\n${catalogBlock(otherReleases ?? [])}\n\n=== ПАРАМЕТРЫ ===\nЖанр: ${i.genre ?? release.genre ?? "не указан"}\nО чём трек: ${i.about ?? "не указано"}\nВайб: ${i.vibe ?? "не указан"}\nРеференсы: ${i.references ?? "нет"}\nДостижения: ${i.achievements ?? "нет"}\nРегион: ${i.region ?? "RU"}\n\nСоздай ПЕРСОНАЛЬНЫЙ питч-пакет.`;

    const workerBody = { release, inputs, profile: prof, tracks: tracks ?? [], catalog: otherReleases ?? [] };
    const output = await callViaWorkerOrDirect("playlist-pitch-pack", workerBody, SYSTEM, userPrompt, 2500);

    await supabase.from("release_tools").upsert({
      user_id: user.id, release_id: releaseId, tool_key: "playlist-pitch-pack",
      is_demo: isDemo, input: inputs, output,
    }, { onConflict: "user_id,release_id,tool_key" });

    return json({ ok: true, is_demo: isDemo, data: output });
  } catch (e) {
    console.error("[playlist-pitch-pack]", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
