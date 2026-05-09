import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "DELETE, POST, OPTIONS",
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

    const { data: existingQuiz, error: fetchQuizError } = await supabase
      .from("smart_quizzes")
      .select("id, status")
      .eq("id", quizId)
      .maybeSingle();

    if (fetchQuizError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch quiz",
        details: fetchQuizError.message,
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
        error: "Only draft quizzes can be deleted",
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: attempts, error: attemptsFetchError } = await supabase
      .from("smart_quiz_attempts")
      .select("id")
      .eq("quiz_id", quizId);

    if (attemptsFetchError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch quiz attempts",
        details: attemptsFetchError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const attemptIds = (attempts || []).map((a: any) => a.id);

    if (attemptIds.length > 0) {
      const { error: attemptAnswersDeleteError } = await supabase
        .from("smart_quiz_attempt_answers")
        .delete()
        .in("attempt_id", attemptIds);

      if (attemptAnswersDeleteError) {
        return new Response(JSON.stringify({
          error: "Failed to delete attempt answers",
          details: attemptAnswersDeleteError.message,
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const { error: attemptsDeleteError } = await supabase
      .from("smart_quiz_attempts")
      .delete()
      .eq("quiz_id", quizId);

    if (attemptsDeleteError) {
      return new Response(JSON.stringify({
        error: "Failed to delete quiz attempts",
        details: attemptsDeleteError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: questions, error: questionsFetchError } = await supabase
      .from("smart_quiz_questions")
      .select("id")
      .eq("quiz_id", quizId);

    if (questionsFetchError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch quiz questions",
        details: questionsFetchError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const questionIds = (questions || []).map((q: any) => q.id);

    if (questionIds.length > 0) {
      const { error: optionsDeleteError } = await supabase
        .from("smart_quiz_options")
        .delete()
        .in("question_id", questionIds);

      if (optionsDeleteError) {
        return new Response(JSON.stringify({
          error: "Failed to delete quiz options",
          details: optionsDeleteError.message,
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const { error: questionsDeleteError } = await supabase
      .from("smart_quiz_questions")
      .delete()
      .eq("quiz_id", quizId);

    if (questionsDeleteError) {
      return new Response(JSON.stringify({
        error: "Failed to delete quiz questions",
        details: questionsDeleteError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: subtopicsDeleteError } = await supabase
      .from("smart_quiz_subtopics")
      .delete()
      .eq("quiz_id", quizId);

    if (subtopicsDeleteError) {
      return new Response(JSON.stringify({
        error: "Failed to delete quiz subtopics",
        details: subtopicsDeleteError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: assignmentsDeleteError } = await supabase
      .from("smart_quiz_assignments")
      .delete()
      .eq("quiz_id", quizId);

    if (assignmentsDeleteError) {
      return new Response(JSON.stringify({
        error: "Failed to delete quiz assignments",
        details: assignmentsDeleteError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error: quizDeleteError } = await supabase
      .from("smart_quizzes")
      .delete()
      .eq("id", quizId);

    if (quizDeleteError) {
      return new Response(JSON.stringify({
        error: "Failed to delete quiz",
        details: quizDeleteError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      success: true,
      message: "Quiz deleted successfully",
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