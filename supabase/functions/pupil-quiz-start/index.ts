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
    const quizId = url.searchParams.get("quizId");

    if (!pupilId || !quizId) {
      return new Response(
        JSON.stringify({ error: "Missing pupilId or quizId" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: assignment, error: assignmentError } = await supabase
      .from("smart_quiz_assignments")
      .select("id, class_id")
      .eq("quiz_id", quizId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (assignmentError) {
      return new Response(JSON.stringify({
        error: "Failed to verify quiz assignment",
        details: assignmentError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (!assignment) {
      return new Response(JSON.stringify({ error: "Quiz is not assigned to this pupil" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("*")
      .eq("id", quizId)
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
      return new Response(JSON.stringify({ error: "Quiz is not available" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const now = new Date();
    const availableFrom = quiz.available_from ? new Date(quiz.available_from) : null;
    const deadlineAt = quiz.deadline_at ? new Date(quiz.deadline_at) : null;

    if (availableFrom && now < availableFrom) {
      return new Response(JSON.stringify({ error: "Quiz is not yet available" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (deadlineAt && now > deadlineAt) {
      return new Response(JSON.stringify({ error: "Quiz deadline is over" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: existingAttempt, error: existingAttemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("id, status")
      .eq("quiz_id", quizId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (existingAttemptError) {
      return new Response(JSON.stringify({
        error: "Failed to check existing attempt",
        details: existingAttemptError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (existingAttempt?.status === "submitted") {
      return new Response(JSON.stringify({ error: "Quiz already submitted" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let attemptId = existingAttempt?.id || null;

    if (!attemptId) {
      const { data: newAttempt, error: insertError } = await supabase
        .from("smart_quiz_attempts")
        .insert({
          quiz_id: quizId,
          pupil_id: pupilId,
          class_id: assignment.class_id,
          status: "started",
          started_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (insertError) {
        return new Response(JSON.stringify({
          error: "Failed to create attempt",
          details: insertError.message,
        }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      attemptId = newAttempt.id;
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
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
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

    const formattedQuestions = (questions || []).map((q: any) => ({
      id: q.id,
      question_text: q.question_text,
      question_type: q.question_type,
      order_index: q.order_index,
      marks: q.marks,
      options: optionsMap[q.id] || [],
    }));

    return new Response(JSON.stringify({
      success: true,
      quiz: {
        id: quiz.id,
        title: quiz.title,
        subject: quiz.subject,
        topic: quiz.topic,
        number_of_questions: quiz.number_of_questions,
        time_limit_minutes: quiz.time_limit_minutes,
        available_from: quiz.available_from,
        deadline_at: quiz.deadline_at,
      },
      attempt_id: attemptId,
      questions: formattedQuestions,
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