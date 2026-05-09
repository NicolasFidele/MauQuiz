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
    const classId = url.searchParams.get("classId");

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
      .eq("teacher_id", teacherId)
      .order("class_name", { ascending: true });

    if (classesError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch teacher classes",
        details: classesError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    let classIds = (classes || []).map((c: any) => c.id);

    if (classId) {
      classIds = classIds.filter((id: string) => id === classId);
    }

    if (classIds.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        classes: classes || [],
        quiz_summaries: [],
      }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { data: quizzes, error: quizzesError } = await supabase
      .from("smart_quizzes")
      .select("id, title, subject, topic, subtopic, class_id, status, created_at")
      .eq("teacher_id", teacherId)
      .eq("status", "published")
      .in("class_id", classIds)
      .order("created_at", { ascending: false });

    if (quizzesError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch teacher quizzes",
        details: quizzesError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const quizIds = (quizzes || []).map((q: any) => q.id);

    const { data: pupils, error: pupilsError } = await supabase
      .from("pupils")
      .select("id, class_id")
      .in("class_id", classIds);

    if (pupilsError) {
      return new Response(JSON.stringify({
        error: "Failed to fetch pupils",
        details: pupilsError.message,
      }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    let attempts: any[] = [];

    if (quizIds.length > 0) {
      const { data: attemptsData, error: attemptsError } = await supabase
        .from("smart_quiz_attempts")
        .select("id, quiz_id, pupil_id, status, score_percent")
        .in("quiz_id", quizIds);

      if (attemptsError) {
        return new Response(JSON.stringify({
          error: "Failed to fetch attempts",
          details: attemptsError.message,
        }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }

      attempts = attemptsData || [];
    }

    const classMap: Record<string, string> = {};
    for (const c of classes || []) {
      classMap[c.id] = c.class_name;
    }

    const pupilsByClass: Record<string, any[]> = {};
    for (const pupil of pupils || []) {
      if (!pupilsByClass[pupil.class_id]) pupilsByClass[pupil.class_id] = [];
      pupilsByClass[pupil.class_id].push(pupil);
    }

    const attemptsByQuiz: Record<string, any[]> = {};
    for (const attempt of attempts) {
      if (!attemptsByQuiz[attempt.quiz_id]) attemptsByQuiz[attempt.quiz_id] = [];
      attemptsByQuiz[attempt.quiz_id].push(attempt);
    }

    const quizSummaries = (quizzes || []).map((quiz: any) => {
      const classPupils = pupilsByClass[quiz.class_id] || [];
      const quizAttempts = attemptsByQuiz[quiz.id] || [];
      const submittedAttempts = quizAttempts.filter((a: any) => a.status === "submitted");

      const avgScore = submittedAttempts.length > 0
        ? Math.round(
            submittedAttempts.reduce(
              (sum: number, a: any) => sum + Number(a.score_percent || 0),
              0,
            ) / submittedAttempts.length,
          )
        : 0;

      const highestScore = submittedAttempts.length > 0
        ? Math.max(...submittedAttempts.map((a: any) => Number(a.score_percent || 0)))
        : 0;

      return {
        quiz_id: quiz.id,
        title: quiz.title,
        subject: quiz.subject,
        topic: quiz.topic,
        subtopic: quiz.subtopic,
        class_id: quiz.class_id,
        class_name: classMap[quiz.class_id] || "",
        total_pupils: classPupils.length,
        submitted_count: submittedAttempts.length,
        average_score: avgScore,
        highest_score: highestScore,
        created_at: quiz.created_at,
      };
    });

    return new Response(JSON.stringify({
      success: true,
      classes: classes || [],
      quiz_summaries: quizSummaries,
    }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({
      error: "Internal server error",
      details: err instanceof Error ? err.message : String(err),
    }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});