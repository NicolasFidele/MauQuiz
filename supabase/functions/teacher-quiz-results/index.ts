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
      .select("id, title, subject, topic, subtopic, class_id, teacher_id, leaderboard_published")
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

    const { data: pupils, error: pupilsError } = await supabase
      .from("pupils")
      .select("id, full_name, username, class_id")
      .eq("class_id", quiz.class_id)
      .order("full_name", { ascending: true });

    if (pupilsError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch pupils",
        details: pupilsError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

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
        duration_seconds
      `)
      .eq("quiz_id", quizId);

    if (attemptsError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch attempts",
        details: attemptsError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const attemptsMap: Record<string, any> = {};
    for (const attempt of attempts || []) {
      attemptsMap[attempt.pupil_id] = attempt;
    }

    const pupilResults = (pupils || []).map((pupil: any) => {
      const attempt = attemptsMap[pupil.id];

      return {
        pupil_id: pupil.id,
        full_name: pupil.full_name,
        username: pupil.username,
        status: attempt ? attempt.status : "not_started",
        attempt_id: attempt?.id || null,
        score_percent: attempt?.score_percent ?? null,
        correct_answers: attempt?.correct_answers ?? null,
        wrong_answers: attempt?.wrong_answers ?? null,
        unanswered_questions: attempt?.unanswered_questions ?? null,
        started_at: attempt?.started_at ?? null,
        submitted_at: attempt?.submitted_at ?? null,
        duration_seconds: attempt?.duration_seconds ?? null,
      };
    });

    const submittedCount = pupilResults.filter((p: any) => p.status === "submitted").length;
    const startedCount = pupilResults.filter(
      (p: any) => p.status === "started" || p.status === "in_progress",
    ).length;
    const notStartedCount = pupilResults.filter((p: any) => p.status === "not_started").length;

    return new Response(JSON.stringify({
      success: true,
      quiz,
      summary: {
        submitted_count: submittedCount,
        started_count: startedCount,
        not_started_count: notStartedCount,
      },
      pupils: pupilResults,
    }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({
      error: "Internal server error",
      details: err instanceof Error ? err.message : String(err),
    }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});