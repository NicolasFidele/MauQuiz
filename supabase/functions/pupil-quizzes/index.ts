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

    if (!pupilId) {
      return new Response(JSON.stringify({ error: "Missing pupilId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase secrets" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: assignments, error: assignmentError } = await supabase
      .from("smart_quiz_assignments")
      .select(`
        id,
        quiz_id,
        class_id,
        smart_quizzes (
          id,
          title,
          subject,
          topic,
          subtopic,
          difficulty,
          number_of_questions,
          time_limit_minutes,
          available_from,
          deadline_at,
          status,
          created_at
        )
      `)
      .eq("pupil_id", pupilId);

    if (assignmentError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch assigned quizzes",
          details: assignmentError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const quizIds = (assignments || [])
      .map((a: any) => a.quiz_id)
      .filter(Boolean);

    let attempts: any[] = [];

    if (quizIds.length > 0) {
      const { data: attemptsData, error: attemptsError } = await supabase
        .from("smart_quiz_attempts")
        .select(`
          id,
          quiz_id,
          pupil_id,
          status,
          started_at,
          submitted_at,
          score_percent
        `)
        .eq("pupil_id", pupilId)
        .in("quiz_id", quizIds);

      if (attemptsError) {
        return new Response(
          JSON.stringify({
            error: "Failed to fetch quiz attempts",
            details: attemptsError.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      attempts = attemptsData || [];
    }

    const attemptsMap: Record<string, any> = {};
    for (const attempt of attempts) {
      attemptsMap[attempt.quiz_id] = attempt;
    }

    const now = new Date();

    const quizzes = (assignments || [])
      .map((assignment: any) => {
        const quiz = assignment.smart_quizzes;
        if (!quiz) return null;

        const attempt = attemptsMap[quiz.id] || null;

        let availability_status = "open";
        let can_open = true;
        let message = "Quiz is available";

        const availableFrom = quiz.available_from
          ? new Date(quiz.available_from)
          : null;

        const deadlineAt = quiz.deadline_at
          ? new Date(quiz.deadline_at)
          : null;

        if (quiz.status !== "published") {
          availability_status = "inactive";
          can_open = false;
          message = "Quiz is not available";
        } else if (attempt?.status === "submitted") {
          availability_status = "submitted";
          can_open = false;
          message = "Quiz already submitted";
        } else if (availableFrom && now < availableFrom) {
          availability_status = "upcoming";
          can_open = false;
          message = "Quiz is not yet available";
        } else if (deadlineAt && now > deadlineAt) {
          availability_status = "expired";
          can_open = false;
          message = "Quiz deadline is over";
        }

        return {
          assignment_id: assignment.id,
          quiz_id: quiz.id,
          title: quiz.title,
          subject: quiz.subject,
          topic: quiz.topic,
          subtopic: quiz.subtopic,
          difficulty: quiz.difficulty,
          number_of_questions: quiz.number_of_questions,
          time_limit_minutes: quiz.time_limit_minutes,
          available_from: quiz.available_from,
          deadline_at: quiz.deadline_at,
          status: quiz.status,
          attempt_id: attempt?.id || null,
          attempt_status: attempt?.status || null,
          submitted_at: attempt?.submitted_at || null,
          score_percent: attempt?.score_percent ?? null,
          availability_status,
          can_open,
          message,
          created_at: quiz.created_at,
        };
      })
      .filter(Boolean)
      .sort((a: any, b: any) => {
        return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
      });

    return new Response(
      JSON.stringify({
        success: true,
        quizzes,
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