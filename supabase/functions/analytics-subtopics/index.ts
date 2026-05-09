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
    const teacherId = url.searchParams.get("teacherId");

    if (!teacherId) {
      return new Response(JSON.stringify({ error: "Missing teacherId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: quizzes, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, subject, topic, subtopic")
      .eq("teacher_id", teacherId)
      .eq("status", "published");

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

    if (!quizzes || quizzes.length === 0) {
      return new Response(
        JSON.stringify({ success: true, subtopics: [] }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const quizIds = quizzes.map((q: any) => q.id);

    const { data: attempts, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("quiz_id, score_percent")
      .eq("status", "submitted")
      .in("quiz_id", quizIds);

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

    const subtopicMap: Record<string, any> = {};

    for (const quiz of quizzes) {
      const key = `${quiz.subject}|||${quiz.topic}|||${quiz.subtopic}`;

      if (!subtopicMap[key]) {
        subtopicMap[key] = {
          subject: quiz.subject,
          topic: quiz.topic,
          subtopic: quiz.subtopic,
          quizzes: [],
          totalScore: 0,
          totalAttempts: 0,
        };
      }

      subtopicMap[key].quizzes.push(quiz.id);
    }

    for (const attempt of attempts || []) {
      for (const key in subtopicMap) {
        if (subtopicMap[key].quizzes.includes(attempt.quiz_id)) {
          subtopicMap[key].totalScore += Number(attempt.score_percent || 0);
          subtopicMap[key].totalAttempts += 1;
        }
      }
    }

    const result = Object.values(subtopicMap)
      .map((item: any) => ({
        subject: item.subject,
        topic: item.topic,
        subtopic: item.subtopic,
        quizzes_count: item.quizzes.length,
        attempts_count: item.totalAttempts,
        average_score:
          item.totalAttempts > 0
            ? Math.round(item.totalScore / item.totalAttempts)
            : 0,
      }))
      .filter((item: any) => item.attempts_count > 0);

    result.sort((a: any, b: any) => a.average_score - b.average_score);

    return new Response(
      JSON.stringify({
        success: true,
        subtopics: result,
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