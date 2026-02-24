import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { callViaWorkerOrDirect, artistBlock, releaseBlock, tracksBlock, catalogBlock, corsHeaders, json } from "../_shared/ai.ts";

const SYSTEM = `Ты — персональный AI-финансовый стратег Aurix для музыкантов.
Бюджет-план ПЕРСОНАЛЬНЫЙ — учитывай артиста, город, жанр, опыт.
Суммы ОБЯЗАНЫ сходиться с общим бюджетом.

Ответ СТРОГО в JSON:
{
  "summary": "персональная бюджетная стратегия",
  "risks": ["..."],
  "must_do": ["..."],
  "anti_waste": ["..."],
  "cheapest_strategy": "...",
  "allocation": [{"category":"...","amount":0,"percent":0,"notes":"...","currency":"₽"}, ...],
  "dont_spend_on": ["..."],
  "must_spend_on": ["..."],
  "next_steps": ["..."]
}
Пиши на русском.`;

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

    const { data: profile } = await supabase.from("profiles")
      .select("plan, artist_name, display_name, name, city, bio")
      .eq("user_id", user.id).single();
    const plan = profile?.plan ?? "start";
    const isDemo = plan === "start";

    const { data: tracks } = await supabase.from("tracks")
      .select("title, isrc, track_number").eq("release_id", releaseId).order("track_number");
    const { data: otherReleases } = await supabase.from("releases")
      .select("title, artist, genre, release_type, status")
      .eq("owner_id", user.id).neq("id", releaseId)
      .order("created_at", { ascending: false }).limit(10);

    const prof = {
      artist_name: profile?.artist_name ?? profile?.display_name ?? profile?.name ?? "",
      city: profile?.city ?? "", bio: profile?.bio ?? "", plan,
    };

    const i = inputs ?? {};
    const t = i.team ?? {};
    const c = i.constraints ?? {};
    const userPrompt = `=== ПРОФИЛЬ АРТИСТА ===\n${artistBlock(prof)}\n\n=== РЕЛИЗ ===\n${releaseBlock(release)}\n\n=== ТРЕКЛИСТ ===\n${tracksBlock(tracks ?? [])}\n${catalogBlock(otherReleases ?? [])}\n\n=== ПАРАМЕТРЫ ===\nБюджет: ${i.totalBudget ?? 30000} ${i.currency ?? "RUB"}\nЦель: ${i.goal ?? "streams"}\nРегион: ${i.region ?? "RU"}\nКоманда: дизайнер=${t.hasDesigner ? "да" : "нет"}, видео=${t.hasVideo ? "да" : "нет"}, PR=${t.hasPR ? "да" : "нет"}\nОграничения: без таргета=${c.noTargetAds ? "да" : "нет"}, без блогеров=${c.noBloggers ? "да" : "нет"}\n\nСоздай ПЕРСОНАЛЬНЫЙ бюджет-план. Суммы = ${i.totalBudget ?? 30000} ${i.currency ?? "RUB"}.`;

    const workerBody = { release, inputs, profile: prof, tracks: tracks ?? [], catalog: otherReleases ?? [] };
    const output = await callViaWorkerOrDirect("budget-plan", workerBody, SYSTEM, userPrompt, 3000);

    await supabase.from("release_tools").upsert({
      user_id: user.id, release_id: releaseId, tool_key: "budget-plan",
      is_demo: isDemo, input: inputs, output,
    }, { onConflict: "user_id,release_id,tool_key" });

    return json({ ok: true, is_demo: isDemo, data: output });
  } catch (e) {
    console.error("[release-budget-plan]", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
