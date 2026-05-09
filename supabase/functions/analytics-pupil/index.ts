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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: attempts, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("quiz_id, score_percent")
      .eq("pupil_id", pupilId)
      .eq("status", "submitted");

    if (attemptError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch attempts",
          details: attemptError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!attempts || attempts.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          overall: {
            average_score: 0,
            attempts: 0,
          },
          subtopics: [],
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const quizIds = attempts.map((a: any) => a.quiz_id);

    const { data: quizzes, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, subject, topic, subtopic")
      .in("id", quizIds);

    if (quizError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch quizzes",
          details: quizError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let totalScore = 0;

    for (const attempt of attempts) {
      totalScore += Number(attempt.score_percent || 0);
    }

    const overallAverage = Math.round(totalScore / attempts.length);

    const subtopicMap: Record<string, any> = {};

    for (const attempt of attempts) {
      const quiz = (quizzes || []).find((q: any) => q.id === attempt.quiz_id);
      if (!quiz) continue;

      const key = `${quiz.subject}|||${quiz.topic}|||${quiz.subtopic}`;

      if (!subtopicMap[key]) {
        subtopicMap[key] = {
          subtopic: quiz.subtopic,
          subject: quiz.subject,
          topic: quiz.topic,
          totalScore: 0,
          count: 0,
        };
      }

      subtopicMap[key].totalScore += Number(attempt.score_percent || 0);
      subtopicMap[key].count += 1;
    }

    const subtopics = Object.values(subtopicMap).map((item: any) => ({
      subtopic: item.subtopic,
      subject: item.subject,
      topic: item.topic,
      average_score: Math.round(item.totalScore / item.count),
    }));

    return new Response(
      JSON.stringify({
        success: true,
        overall: {
          average_score: overallAverage,
          attempts: attempts.length,
        },
        subtopics,
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