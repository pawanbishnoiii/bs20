import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const authorization = request.headers.get("Authorization");
  if (!authorization)
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  const client = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authorization } } },
  );
  const body = request.method === "POST" ? await request.json().catch(() => ({})) : {};
  const { data, error } = await client.rpc("refresh_my_study_plan", {
    p_plan_date: typeof body.plan_date === "string" ? body.plan_date : undefined,
  });
  return new Response(JSON.stringify(error ? { error: error.message } : { created: data }), {
    status: error ? 400 : 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
