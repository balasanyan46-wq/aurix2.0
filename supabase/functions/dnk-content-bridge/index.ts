import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { callViaWorkerOrDirect, releaseBlock, corsHeaders, json } from "../_shared/ai.ts";

const SYSTEM = `Ты — DNK→Content Bridge AURIX.
Верни JSON:
{
  "summary":"...",
  "content_pillars":["..."],
  "tone_rules":["..."],
  "hooks":["..."],
  "days":[{"day":1,"format":"...","idea":"...","cta":"..."}]
}`;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ ok: false, error: "Unauthorized" }, 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
    if (authErr || !user) return json({ ok: false, error: "Unauthorized" }, 401);

    const { releaseId, inputs } = await req.json();
    if (!releaseId) return json({ ok: false, error: "Missing releaseId" }, 400);

    const { data: release } = await supabase
      .from("releases")
      .select("id, owner_id, title, artist, genre, release_type, status")
      .eq("id", releaseId)
      .single();
    if (!release) return json({ ok: false, error: "Release not found" }, 404);
    if (release.owner_id !== user.id) return json({ ok: false, error: "Forbidden" }, 403);

    const { data: latestDnk } = await supabase
      .from("dnk_results")
      .select("result_json, created_at")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    const dnk = inputs?.dnk ?? latestDnk?.result_json ?? {};
    const userPrompt = `=== РЕЛИЗ ===\n${releaseBlock(release)}\n\n=== DNK JSON ===\n${JSON.stringify(dnk)}\n\nСобери bridge-output для 14-дневного контент-плана.`;

    const output = await callViaWorkerOrDirect(
      "dnk-content-bridge",
      { release, inputs: { ...(inputs ?? {}), dnk } },
      SYSTEM,
      userPrompt,
      2800,
    );

    await supabase.from("release_tools").upsert({
      user_id: user.id,
      release_id: release.id,
      tool_key: "dnk-content-bridge",
      is_demo: false,
      input: { ...(inputs ?? {}), dnk_used: dnk },
      output,
    }, { onConflict: "user_id,release_id,tool_key" });

    return json({ ok: true, is_demo: false, data: output });
  } catch (e) {
    console.error("[dnk-content-bridge]", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
