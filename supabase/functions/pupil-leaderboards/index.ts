import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
      return new Response(JSON.stringify({ error: "Missing Supabase secrets" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: assignments, error: assignmentsError } = await supabase
      .from("smart_quiz_assignments")
      .select(`
        quiz_id,
        class_id,
        smart_quizzes (
          id,
          title,
          subject,
          topic,
          subtopic,
          status,
          leaderboard_published,
          created_at
        )
      `)
      .eq("pupil_id", pupilId);

    if (assignmentsError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch leaderboard assignments",
          details: assignmentsError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const quizzes = (assignments || [])
      .map((assignment: any) => assignment.smart_quizzes)
      .filter(
        (quiz: any) =>
          quiz &&
          quiz.status === "published" &&
          quiz.leaderboard_published === true,
      );

    const quizIds = quizzes.map((q: any) => q.id);

    let attempts: any[] = [];

    if (quizIds.length > 0) {
      const { data: attemptsData, error: attemptsError } = await supabase
        .from("smart_quiz_attempts")
        .select("quiz_id, status, score_percent")
        .eq("pupil_id", pupilId)
        .in("quiz_id", quizIds);

      if (attemptsError) {
        return new Response(
          JSON.stringify({
            error: "Failed to fetch pupil leaderboard attempts",
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

    const leaderboards = quizzes.map((quiz: any) => {
      const attempt = attemptsMap[quiz.id] || null;

      return {
        quiz_id: quiz.id,
        title: quiz.title,
        subject: quiz.subject,
        topic: quiz.topic,
        subtopic: quiz.subtopic,
        participated: attempt?.status === "submitted",
        score_percent: attempt?.score_percent ?? null,
        created_at: quiz.created_at,
      };
    });

    return new Response(
      JSON.stringify({
        success: true,
        leaderboards,
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