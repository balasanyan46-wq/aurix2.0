import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { corsHeaders, json } from "../_shared/ai.ts";

type PlanSlug = "start" | "breakthrough" | "empire";
type BillingPeriod = "monthly" | "yearly";

const allowedPlans: PlanSlug[] = ["start", "breakthrough", "empire"];
const allowedPeriods: BillingPeriod[] = ["monthly", "yearly"];

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

    // Verify admin privileges (via profiles.role)
    const { data: me } = await supabase
      .from("profiles")
      .select("role")
      .eq("user_id", user.id)
      .maybeSingle();

    if ((me?.role ?? "artist") !== "admin") {
      return json({ ok: false, error: "Forbidden" }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const userId = body?.userId ?? body?.user_id;
    const plan = body?.plan as PlanSlug | undefined;
    const billingPeriod = (body?.billingPeriod ?? body?.billing_period) as BillingPeriod | undefined;

    if (!userId || typeof userId !== "string") {
      return json({ ok: false, error: "Missing userId" }, 400);
    }
    if (!plan || !allowedPlans.includes(plan)) {
      return json({ ok: false, error: "Invalid plan" }, 400);
    }
    if (billingPeriod && !allowedPeriods.includes(billingPeriod)) {
      return json({ ok: false, error: "Invalid billingPeriod" }, 400);
    }

    // Upsert subscription (this is the ONLY manual plan assignment path).
    const { error: upsertErr } = await supabase
      .from("subscriptions")
      .upsert(
        {
          user_id: userId,
          plan,
          status: "active",
          billing_period: billingPeriod ?? "monthly",
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      );

    if (upsertErr) {
      return json({ ok: false, error: upsertErr.message }, 400);
    }

    return json({ ok: true });
  } catch (e) {
    console.error("[admin-subscriptions-assign]", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});

