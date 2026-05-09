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

    const { data: classes, error: classesError } = await supabase
      .from("classes")
      .select("id, class_name")
      .eq("teacher_id", teacherId);

    if (classesError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch classes",
          details: classesError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const classMap: Record<string, string> = {};
    for (const c of classes || []) {
      classMap[c.id] = c.class_name;
    }

    const { data: quizzes, error: quizzesError } = await supabase
      .from("smart_quizzes")
      .select("id, title, subject, topic, subtopic, class_id, number_of_questions, status, created_at")
      .eq("teacher_id", teacherId)
      .eq("status", "published")
      .order("created_at", { ascending: false });

    if (quizzesError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch quizzes",
          details: quizzesError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!quizzes || quizzes.length === 0) {
      return new Response(JSON.stringify({ success: true, quizzes: [] }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const quizIds = quizzes.map((q: any) => q.id);
    const classIds = [...new Set(quizzes.map((q: any) => q.class_id))];

    const { data: pupils, error: pupilsError } = await supabase
      .from("pupils")
      .select("id, class_id")
      .in("class_id", classIds);

    if (pupilsError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch pupils",
          details: pupilsError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select("quiz_id, pupil_id, status, score_percent")
      .in("quiz_id", quizIds);

    if (attemptsError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch attempts",
          details: attemptsError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const pupilsByClass: Record<string, any[]> = {};
    for (const pupil of pupils || []) {
      if (!pupilsByClass[pupil.class_id]) {
        pupilsByClass[pupil.class_id] = [];
      }
      pupilsByClass[pupil.class_id].push(pupil);
    }

    const attemptsByQuiz: Record<string, any[]> = {};
    for (const attempt of attempts || []) {
      if (!attemptsByQuiz[attempt.quiz_id]) {
        attemptsByQuiz[attempt.quiz_id] = [];
      }
      attemptsByQuiz[attempt.quiz_id].push(attempt);
    }

    const result = quizzes
      .map((quiz: any) => {
        const classPupils = pupilsByClass[quiz.class_id] || [];
        const quizAttempts = attemptsByQuiz[quiz.id] || [];

        const submitted = quizAttempts.filter((a: any) => a.status === "submitted");
        const started = quizAttempts.filter(
          (a: any) => a.status === "started" || a.status === "in_progress",
        );

        const submittedScores = submitted.map((a: any) =>
          Number(a.score_percent || 0)
        );

        const averageScore =
          submittedScores.length > 0
            ? Math.round(
                submittedScores.reduce((sum: number, score: number) => sum + score, 0) /
                  submittedScores.length,
              )
            : 0;

        const highestScore =
          submittedScores.length > 0 ? Math.max(...submittedScores) : 0;

        const lowestScore =
          submittedScores.length > 0 ? Math.min(...submittedScores) : 0;

        const notAttempted = Math.max(
          0,
          classPupils.length - submitted.length - started.length,
        );

        return {
          quiz_id: quiz.id,
          title: quiz.title,
          subject: quiz.subject,
          topic: quiz.topic,
          subtopic: quiz.subtopic,
          class_id: quiz.class_id,
          class_name: classMap[quiz.class_id] || "",
          number_of_questions: quiz.number_of_questions,
          submitted_count: submitted.length,
          started_count: started.length,
          not_attempted_count: notAttempted,
          average_score: averageScore,
          highest_score: highestScore,
          lowest_score: lowestScore,
          created_at: quiz.created_at,
        };
      })
      .filter((quiz: any) => quiz.submitted_count > 0);

    return new Response(JSON.stringify({ success: true, quizzes: result }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
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