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
    const quizId = url.searchParams.get("quizId");

    if (!quizId) {
      return new Response(JSON.stringify({ error: "Missing quizId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: existingQuiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, status, class_id")
      .eq("id", quizId)
      .maybeSingle();

    if (quizError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch quiz",
        details: quizError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!existingQuiz) {
      return new Response(JSON.stringify({ error: "Quiz not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (existingQuiz.status !== "draft") {
      return new Response(JSON.stringify({
        error: "Only draft quizzes can be published",
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: updateError } = await supabase
      .from("smart_quizzes")
      .update({ status: "published" })
      .eq("id", quizId);

    if (updateError) {
      return new Response(JSON.stringify({
        error: "Failed to publish quiz",
        details: updateError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: pupils, error: pupilsError } = await supabase
      .from("pupils")
      .select("id")
      .eq("class_id", existingQuiz.class_id);

    if (pupilsError) {
      return new Response(JSON.stringify({
        error: "Quiz published, but failed to fetch pupils for assignments",
        details: pupilsError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const assignmentRows = (pupils || []).map((pupil: any) => ({
      quiz_id: quizId,
      pupil_id: pupil.id,
      class_id: existingQuiz.class_id,
    }));

    if (assignmentRows.length > 0) {
      const { error: assignmentError } = await supabase
        .from("smart_quiz_assignments")
        .upsert(assignmentRows, {
          onConflict: "quiz_id,pupil_id",
        });

      if (assignmentError) {
        return new Response(JSON.stringify({
          error: "Quiz published, but failed to assign quiz to pupils",
          details: assignmentError.message,
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: "Quiz published successfully",
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