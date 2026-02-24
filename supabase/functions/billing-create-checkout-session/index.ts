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

    const body = await req.json().catch(() => ({}));
    const plan = body?.plan as PlanSlug | undefined;
    const billingPeriod = (body?.billingPeriod ?? body?.billing_period) as BillingPeriod | undefined;

    if (!plan || !allowedPlans.includes(plan)) {
      return json({ ok: false, error: "Invalid plan" }, 400);
    }
    if (billingPeriod && !allowedPeriods.includes(billingPeriod)) {
      return json({ ok: false, error: "Invalid billingPeriod" }, 400);
    }

    // Stub: do NOT update DB here.
    // Later: create Stripe (or other) checkout session and return its URL.
    const url =
      `https://aurix.example/checkout?plan=${encodeURIComponent(plan)}` +
      `&period=${encodeURIComponent(billingPeriod ?? "monthly")}` +
      `&uid=${encodeURIComponent(user.id)}`;

    return json({ ok: true, url });
  } catch (e) {
    console.error("[billing-create-checkout-session]", e);
    return json({ ok: false, error: String(e) }, 500);
  }
});

