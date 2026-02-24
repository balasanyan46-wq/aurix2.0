import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ ok: false, error: "Unauthorized" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const workerUrl = Deno.env.get("CF_WORKER_URL")!;
    const internalKey = Deno.env.get("AURIX_INTERNAL_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
    if (authErr || !user) return json({ ok: false, error: "Unauthorized" }, 401);

    const { releaseId, inputs } = await req.json();
    if (!releaseId || !inputs) return json({ ok: false, error: "Missing releaseId or inputs" }, 400);

    const { data: release, error: relErr } = await supabase
      .from("releases").select("owner_id, title, artist, release_type")
      .eq("id", releaseId).single();
    if (relErr || !release) return json({ ok: false, error: "Release not found" }, 404);
    if (release.owner_id !== user.id) return json({ ok: false, error: "Forbidden" }, 403);

    const { data: profile } = await supabase
      .from("profiles").select("plan").eq("user_id", user.id).single();
    const plan = profile?.plan ?? "start";
    const isDemo = plan === "start";

    const cfRes = await fetch(`${workerUrl}/v1/tools/budget-plan`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-AURIX-INTERNAL-KEY": internalKey,
      },
      body: JSON.stringify({ release, inputs }),
    });
    const cfBody = await cfRes.json() as any;
    if (!cfBody.ok) return json({ ok: false, error: cfBody.error ?? "AI generation failed" }, 502);

    const output = cfBody.data;

    await supabase.from("release_tools").upsert({
      user_id: user.id,
      release_id: releaseId,
      tool_key: "budget-plan",
      is_demo: isDemo,
      input: inputs,
      output,
    }, { onConflict: "user_id,release_id,tool_key" });

    return json({ ok: true, is_demo: isDemo, data: output });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
