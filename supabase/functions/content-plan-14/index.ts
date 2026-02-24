import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { callViaWorkerOrDirect, artistBlock, releaseBlock, tracksBlock, corsHeaders, json } from "../_shared/ai.ts";

const SYSTEM = `Ты — AI-контент-стратег Aurix. Создаёшь 14-дневный контент-план для продвижения релиза.
План УНИКАЛЬНЫЙ для конкретного артиста и трека. Каждый день уникальный.

Ответ СТРОГО в JSON:
{
  "strategy": "персональная стратегия (2-3 предложения)",
  "days": [{"day":1,"format":"Reels/TikTok/...","hook":"...","script":"сценарий 3-5 предложений","shotlist":["..."],"cta":"..."}, ... до 14]
}
Сценарии детальные. Шотлист конкретный. Хуки разнообразные. Пиши на русском.`;

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
      .select("title, isrc, track_number").eq("release_id", releaseId).order("track_number");

    const prof = {
      artist_name: profile?.artist_name ?? profile?.display_name ?? profile?.name ?? "",
      city: profile?.city ?? "", bio: profile?.bio ?? "", plan,
    };

    const i = inputs ?? {};
    const userPrompt = `=== ПРОФИЛЬ АРТИСТА ===\n${artistBlock(prof)}\n\n=== РЕЛИЗ ===\n${releaseBlock(release)}\n\n=== ТРЕКЛИСТ ===\n${tracksBlock(tracks ?? [])}\n\n=== ПАРАМЕТРЫ ===\nЦель: ${i.goal ?? "streams"}\nРегион: ${i.region ?? "RU"}\nПлатформы: ${(i.platforms ?? ["instagram", "tiktok"]).join(", ")}\nВайб: ${i.vibe ?? "не указан"}\nАудитория: ${i.audience ?? "не указана"}\n\nСоздай 14-дневный ПЕРСОНАЛЬНЫЙ контент-план.`;

    const workerBody = { release, inputs, profile: prof, tracks: tracks ?? [] };
    const output = await callViaWorkerOrDirect("content-plan-14", workerBody, SYSTEM, userPrompt, 4000);

    await supabase.from("release_tools").upsert({
      user_id: user.id, release_id: releaseId, tool_key: "content-plan-14",
      is_demo: isDemo, input: inputs, output,
    }, { onConflict: "user_id,release_id,tool_key" });

    return json({ ok: true, is_demo: isDemo, data: output });
  } catch (e) {
    console.error("[content-plan-14]", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
