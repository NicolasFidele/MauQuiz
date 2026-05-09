import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const url = new URL(req.url);
    const teacherId = url.searchParams.get("teacherId");
    const quizId = url.searchParams.get("quizId");

    if (!teacherId || !quizId) {
      return new Response(JSON.stringify({ error: "Missing teacherId or quizId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, teacher_id, status, leaderboard_published")
      .eq("id", quizId)
      .eq("teacher_id", teacherId)
      .maybeSingle();

    if (quizError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch quiz",
        details: quizError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (!quiz) {
      return new Response(JSON.stringify({ error: "Quiz not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (quiz.status !== "published") {
      return new Response(JSON.stringify({
        error: "Leaderboard can only be published for a published quiz",
      }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (quiz.leaderboard_published === true) {
      return new Response(JSON.stringify({
        success: true,
        message: "Leaderboard already published",
      }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { error: updateError } = await supabase
      .from("smart_quizzes")
      .update({ leaderboard_published: true })
      .eq("id", quizId);

    if (updateError) {
      return new Response(JSON.stringify({
        error: "Failed to publish leaderboard",
        details: updateError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({
      success: true,
      message: "Leaderboard published successfully",
    }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({
      error: "Internal server error",
      details: err instanceof Error ? err.message : String(err),
    }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});