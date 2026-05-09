import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const url = new URL(req.url);
    const subject = url.searchParams.get("subject");
    const topic = url.searchParams.get("topic");

    if (!subject || !topic) {
      return new Response(JSON.stringify({ error: "Missing subject or topic" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data, error } = await supabase
      .from("curriculum_items")
      .select("subtopic")
      .eq("subject", subject)
      .eq("topic", topic)
      .eq("is_active", true);

    if (error) {
      return new Response(JSON.stringify({
        error: "Failed to fetch curriculum subtopics",
        details: error.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const subtopics = [...new Set((data || []).map((row: any) => row.subtopic))]
      .filter(Boolean)
      .sort();

    return new Response(JSON.stringify({
      success: true,
      subtopics,
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({
      error: "Internal server error",
      details: err instanceof Error ? err.message : String(err),
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});