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

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("*")
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

    if (!quiz) {
      return new Response(JSON.stringify({ error: "Quiz not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: questions, error: questionsError } = await supabase
      .from("smart_quiz_questions")
      .select("*")
      .eq("quiz_id", quizId)
      .order("order_index", { ascending: true });

    if (questionsError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch questions",
        details: questionsError.message,
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const questionIds = (questions || []).map((q: any) => q.id);

    let options: any[] = [];

    if (questionIds.length > 0) {
      const { data: optionsData, error: optionsError } = await supabase
        .from("smart_quiz_options")
        .select("*")
        .in("question_id", questionIds)
        .order("order_index", { ascending: true });

      if (optionsError) {
        return new Response(JSON.stringify({
          error: "Failed to fetch options",
          details: optionsError.message,
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      options = optionsData || [];
    }

    const optionsByQuestion: Record<string, any[]> = {};

    for (const option of options) {
      if (!optionsByQuestion[option.question_id]) {
        optionsByQuestion[option.question_id] = [];
      }

      optionsByQuestion[option.question_id].push(option);
    }

    const formattedQuestions = (questions || []).map((q: any) => ({
      ...q,
      options: optionsByQuestion[q.id] || [],
    }));

    return new Response(JSON.stringify({
      success: true,
      quiz,
      questions: formattedQuestions,
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