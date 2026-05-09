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
    const pupilId = url.searchParams.get("pupilId");
    const attemptId = url.searchParams.get("attemptId");

    if (!pupilId || !attemptId) {
      return new Response(
        JSON.stringify({
          error: "Missing pupilId or attemptId",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({
          error: "Missing Supabase environment variables",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: attempt, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select(
        `
        *,
        smart_quizzes (
          id,
          title,
          subject,
          topic,
          subtopic,
          number_of_questions
        )
      `,
      )
      .eq("id", attemptId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (attemptError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch attempt",
          details: attemptError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!attempt) {
      return new Response(
        JSON.stringify({
          error: "Result not found",
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { data: answerRows, error: answersError } = await supabase
      .from("smart_quiz_attempt_answers")
      .select(
        `
        attempt_id,
        question_id,
        answer_text,
        is_correct,
        marks_awarded,
        smart_quiz_questions (
          id,
          question_text,
          question_type,
          correct_answer_text,
          explanation,
          marks
        )
      `,
      )
      .eq("attempt_id", attemptId);

    if (answersError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch result answers",
          details: answersError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const questionIds = (answerRows || [])
      .map((row: any) => row.smart_quiz_questions?.id)
      .filter(Boolean);

    let options: any[] = [];

    if (questionIds.length > 0) {
      const { data: optionsData, error: optionsError } = await supabase
        .from("smart_quiz_options")
        .select("*")
        .in("question_id", questionIds)
        .order("order_index", { ascending: true });

      if (optionsError) {
        return new Response(
          JSON.stringify({
            error: "Failed to fetch question options",
            details: optionsError.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      options = optionsData || [];
    }

    const optionsMap: Record<string, any[]> = {};

    for (const option of options) {
      if (!optionsMap[option.question_id]) {
        optionsMap[option.question_id] = [];
      }

      optionsMap[option.question_id].push(option);
    }

    const review = (answerRows || []).map((row: any) => {
      const q = row.smart_quiz_questions;

      let reviewCorrectAnswerText = q?.correct_answer_text || "";

      if (q?.question_type === "mcq" || q?.question_type === "true_false") {
        const correctOption = (optionsMap[q.id] || []).find(
          (o) => o.is_correct === true,
        );

        reviewCorrectAnswerText =
          correctOption?.option_text || reviewCorrectAnswerText;
      }

      return {
        question_id: q?.id,
        question_text: q?.question_text || "",
        question_type: q?.question_type || "",
        pupil_answer_text: row.answer_text || "",
        correct_answer_text: reviewCorrectAnswerText,
        explanation: q?.explanation || "",
        marks: q?.marks || 1,
        marks_awarded: row.marks_awarded || 0,
        is_correct: row.is_correct === true,
        options: optionsMap[q?.id] || [],
      };
    });

    const totalPossible = review.reduce(
      (sum: number, item: any) => sum + Number(item.marks || 0),
      0,
    );

    const score = review.reduce(
      (sum: number, item: any) => sum + Number(item.marks_awarded || 0),
      0,
    );

    return new Response(
      JSON.stringify({
        success: true,
        quizTitle: attempt.smart_quizzes?.title || "",
        score,
        total_possible: totalPossible,
        review,
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