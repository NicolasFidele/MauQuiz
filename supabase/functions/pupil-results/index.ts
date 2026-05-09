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
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const url = new URL(req.url);
    const pupilId = url.searchParams.get("pupilId");

    if (!pupilId) {
      return new Response(
        JSON.stringify({
          error: "Missing pupilId",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
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
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select(`
        id,
        quiz_id,
        pupil_id,
        status,
        started_at,
        submitted_at,
        score_percent,
        correct_answers,
        wrong_answers,
        unanswered_questions,
        duration_seconds,
        smart_quizzes (
          id,
          title,
          subject,
          topic,
          subtopic,
          number_of_questions
        )
      `)
      .eq("pupil_id", pupilId)
      .eq("status", "submitted")
      .order("submitted_at", { ascending: false });

    if (attemptsError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch pupil results",
          details: attemptsError.message,
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    const results = (attempts || []).map((attempt: any) => ({
      attempt_id: attempt.id,
      quiz_id: attempt.quiz_id,
      title: attempt.smart_quizzes?.title || "",
      subject: attempt.smart_quizzes?.subject || "",
      topic: attempt.smart_quizzes?.topic || "",
      subtopic: attempt.smart_quizzes?.subtopic || "",
      number_of_questions: attempt.smart_quizzes?.number_of_questions || 0,
      submitted_at: attempt.submitted_at,
      score_percent: attempt.score_percent ?? 0,
      correct_answers: attempt.correct_answers ?? 0,
      wrong_answers: attempt.wrong_answers ?? 0,
      unanswered_questions: attempt.unanswered_questions ?? 0,
      duration_seconds: attempt.duration_seconds ?? 0,
    }));

    return new Response(
      JSON.stringify({
        success: true,
        results,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details: err instanceof Error ? err.message : String(err),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});