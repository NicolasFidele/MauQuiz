import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

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
      .select("id, title, subject, topic, subtopic, number_of_questions")
      .eq("id", quizId)
      .maybeSingle();

    if (quizError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch quiz",
          details: quizError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!quiz) {
      return new Response(JSON.stringify({ error: "Quiz not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: questions, error: questionsError } = await supabase
      .from("smart_quiz_questions")
      .select("id, question_text, order_index, marks")
      .eq("quiz_id", quizId)
      .order("order_index", { ascending: true });

    if (questionsError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch questions",
          details: questionsError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const questionIds = (questions || []).map((q: any) => q.id);

    let answers: any[] = [];

    if (questionIds.length > 0) {
      const { data: answersData, error: answersError } = await supabase
        .from("smart_quiz_attempt_answers")
        .select("question_id, is_correct, answer_text")
        .in("question_id", questionIds);

      if (answersError) {
        return new Response(
          JSON.stringify({
            error: "Failed to fetch answers",
            details: answersError.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      answers = answersData || [];
    }

    const analytics = (questions || []).map((question: any) => {
      const qAnswers = answers.filter((a: any) => a.question_id === question.id);

      const correct = qAnswers.filter((a: any) => a.is_correct === true).length;

      const wrong = qAnswers.filter(
        (a: any) =>
          a.answer_text &&
          String(a.answer_text).trim() !== "" &&
          a.is_correct !== true,
      ).length;

      const skipped = qAnswers.filter(
        (a: any) => !a.answer_text || String(a.answer_text).trim() === "",
      ).length;

      const totalResponses = qAnswers.length;

      const correctRate =
        totalResponses > 0 ? Math.round((correct / totalResponses) * 100) : 0;

      return {
        question_id: question.id,
        question_text: question.question_text,
        order_index: question.order_index,
        total_responses: totalResponses,
        correct_count: correct,
        wrong_count: wrong,
        skipped_count: skipped,
        correct_rate: correctRate,
      };
    });

    const sortedByDifficulty = [...analytics].sort(
      (a: any, b: any) => a.correct_rate - b.correct_rate,
    );

    const hardestQuestion =
      sortedByDifficulty.length > 0 ? sortedByDifficulty[0] : null;

    const easiestQuestion =
      sortedByDifficulty.length > 0
        ? sortedByDifficulty[sortedByDifficulty.length - 1]
        : null;

    return new Response(
      JSON.stringify({
        success: true,
        quiz,
        questions: analytics,
        highlights: {
          hardest_question: hardestQuestion,
          easiest_question: easiestQuestion,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details: err instanceof Error ? err.message : String(err),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});