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
    const quizId = url.searchParams.get("quizId");

    if (!pupilId || !quizId) {
      return new Response(
        JSON.stringify({ error: "Missing pupilId or quizId" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
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

    const { data: assignment, error: assignmentError } = await supabase
      .from("smart_quiz_assignments")
      .select("id, class_id")
      .eq("quiz_id", quizId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (assignmentError) {
      return new Response(
        JSON.stringify({
          error: "Failed to verify leaderboard assignment",
          details: assignmentError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!assignment) {
      return new Response(
        JSON.stringify({ error: "This leaderboard is not assigned to this pupil" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, title, subject, topic, subtopic, leaderboard_published, status")
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

    if (quiz.status !== "published" || quiz.leaderboard_published !== true) {
      return new Response(JSON.stringify({ error: "Leaderboard is not available" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select("id, pupil_id, score_percent, duration_seconds, submitted_at, status")
      .eq("quiz_id", quizId)
      .eq("status", "submitted");

    if (attemptsError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch leaderboard attempts",
          details: attemptsError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const submittedAttempts = attempts || [];
    const submittedPupilIds = submittedAttempts.map((a: any) => a.pupil_id);

    let pupils: any[] = [];

    if (submittedPupilIds.length > 0) {
      const { data: pupilsData, error: pupilsError } = await supabase
        .from("pupils")
        .select("id, full_name, username")
        .in("id", submittedPupilIds);

      if (pupilsError) {
        return new Response(
          JSON.stringify({
            error: "Failed to fetch leaderboard pupils",
            details: pupilsError.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      pupils = pupilsData || [];
    }

    const pupilMap: Record<string, any> = {};
    for (const pupil of pupils) {
      pupilMap[pupil.id] = pupil;
    }

    const ranked = submittedAttempts
      .map((attempt: any) => ({
        pupil_id: attempt.pupil_id,
        full_name: pupilMap[attempt.pupil_id]?.full_name || "Pupil",
        username: pupilMap[attempt.pupil_id]?.username || "",
        score_percent: Number(attempt.score_percent || 0),
        duration_seconds: Number(attempt.duration_seconds || 0),
        submitted_at: attempt.submitted_at,
      }))
      .sort((a: any, b: any) => {
        if (b.score_percent !== a.score_percent) {
          return b.score_percent - a.score_percent;
        }

        if (a.duration_seconds !== b.duration_seconds) {
          return a.duration_seconds - b.duration_seconds;
        }

        return new Date(a.submitted_at).getTime() -
          new Date(b.submitted_at).getTime();
      });

    const podium = ranked.slice(0, 3).map((item: any, index: number) => ({
      place: index + 1,
      ...item,
    }));

    const currentPupilEntry =
      ranked.find((item: any) => item.pupil_id === pupilId) || null;

    return new Response(
      JSON.stringify({
        success: true,
        quiz: {
          id: quiz.id,
          title: quiz.title,
          subject: quiz.subject,
          topic: quiz.topic,
          subtopic: quiz.subtopic,
        },
        podium,
        current_pupil: currentPupilEntry,
        participated: !!currentPupilEntry,
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