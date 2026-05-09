import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function calculateDurationSeconds(startedAt: string | null, submittedAt: string) {
  if (!startedAt) return null;
  const start = new Date(startedAt).getTime();
  const end = new Date(submittedAt).getTime();
  if (Number.isNaN(start) || Number.isNaN(end)) return null;
  return Math.max(0, Math.round((end - start) / 1000));
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const pupilId = url.searchParams.get("pupilId");
    const quizId = url.searchParams.get("quizId");

    if (!pupilId || !quizId) {
      return new Response(
        JSON.stringify({ error: "Missing pupilId or quizId" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const body = await req.json();
    const answers = body.answers;

    if (!Array.isArray(answers) || answers.length === 0) {
      return new Response(JSON.stringify({ error: "Answers are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: attempt, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("*")
      .eq("quiz_id", quizId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (attemptError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch attempt",
        details: attemptError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (!attempt) {
      return new Response(JSON.stringify({ error: "Attempt not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (attempt.status === "submitted") {
      return new Response(JSON.stringify({ error: "Quiz already submitted" }), {
        status: 400,
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
        error: "Failed to fetch quiz questions",
        details: questionsError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const questionIds = (questions || []).map((q: any) => q.id);

    let options: any[] = [];

    if (questionIds.length > 0) {
      const { data: optionsData, error: optionsError } = await supabase
        .from("smart_quiz_options")
        .select("*")
        .in("question_id", questionIds);

      if (optionsError) {
        return new Response(JSON.stringify({
          error: "Failed to fetch options",
          details: optionsError.message,
        }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
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

    const { error: deleteExistingAnswersError } = await supabase
      .from("smart_quiz_attempt_answers")
      .delete()
      .eq("attempt_id", attempt.id);

    if (deleteExistingAnswersError) {
      return new Response(JSON.stringify({
        error: "Failed to reset previous answers",
        details: deleteExistingAnswersError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    let totalScore = 0;
    let totalPossible = 0;
    const answerRows: any[] = [];
    const review: any[] = [];

    for (const question of questions || []) {
      totalPossible += Number(question.marks || 1);

      const submitted = answers.find((a: any) => a.question_id === question.id);
      const pupilAnswer = submitted?.answer_text ?? "";

      let isCorrect = false;
      let reviewCorrectAnswerText = question.correct_answer_text || "";

      if (question.question_type === "fill_blank") {
        isCorrect =
          String(pupilAnswer).trim().toLowerCase() ===
          String(question.correct_answer_text || "").trim().toLowerCase();
      } else {
        const correctOption = (optionsMap[question.id] || []).find(
          (o) => o.is_correct === true,
        );

        const correctText =
          correctOption?.option_text || question.correct_answer_text || "";

        reviewCorrectAnswerText = correctText;

        isCorrect =
          String(pupilAnswer).trim().toLowerCase() ===
          String(correctText).trim().toLowerCase();
      }

      const awardedMarks = isCorrect ? Number(question.marks || 1) : 0;
      totalScore += awardedMarks;

      answerRows.push({
        attempt_id: attempt.id,
        question_id: question.id,
        selected_option_id: null,
        answer_text: pupilAnswer,
        is_correct: isCorrect,
        marks_awarded: awardedMarks,
        answered_at: new Date().toISOString(),
      });

      review.push({
        question_id: question.id,
        question_text: question.question_text,
        question_type: question.question_type,
        pupil_answer_text: pupilAnswer,
        correct_answer_text: reviewCorrectAnswerText,
        explanation: question.explanation,
        marks: question.marks,
        marks_awarded: awardedMarks,
        is_correct: isCorrect,
        options: optionsMap[question.id] || [],
      });
    }

    const { error: insertAnswersError } = await supabase
      .from("smart_quiz_attempt_answers")
      .insert(answerRows);

    if (insertAnswersError) {
      return new Response(JSON.stringify({
        error: "Failed to save attempt answers",
        details: insertAnswersError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const submittedAt = new Date().toISOString();

    const scorePercent =
      totalPossible > 0 ? Math.round((totalScore / totalPossible) * 100) : 0;

    const correctAnswers = answerRows.filter((a) => a.is_correct).length;
    const wrongAnswers = answerRows.filter(
      (a) => a.answer_text && !a.is_correct,
    ).length;
    const unansweredQuestions = answerRows.filter(
      (a) => !a.answer_text || String(a.answer_text).trim() === "",
    ).length;

    const duration = calculateDurationSeconds(attempt.started_at, submittedAt);

    const { error: updateAttemptError } = await supabase
      .from("smart_quiz_attempts")
      .update({
        status: "submitted",
        submitted_at: submittedAt,
        score_percent: scorePercent,
        correct_answers: correctAnswers,
        wrong_answers: wrongAnswers,
        unanswered_questions: unansweredQuestions,
        duration_seconds: duration,
      })
      .eq("id", attempt.id);

    if (updateAttemptError) {
      return new Response(JSON.stringify({
        error: "Failed to finalize attempt",
        details: updateAttemptError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({
      success: true,
      message: "Quiz submitted successfully",
      attempt_id: attempt.id,
      score: totalScore,
      total_possible: totalPossible,
      score_percent: scorePercent,
      review,
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({
      error: "Internal server error",
      details: err instanceof Error ? err.message : String(err),
    }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});