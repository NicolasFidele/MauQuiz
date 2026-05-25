import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Allow requests from Flutter application.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};
// Start Edge Function and handle requests.
serve(async (req) => {
  // Handle browser preflight requests.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  // Read parameters sent from Flutter.
  try {
    const url = new URL(req.url);
    // Retrieve teacher identifier.
    const teacherId = url.searchParams.get("teacherId");
    // Validate required input.
    if (!teacherId) {
      return new Response(JSON.stringify({ error: "Missing teacherId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    // Create secure database connection.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    // READ → classes - Retrieve teacher classes.
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
    // Extract class identifiers.
    const classIds = (classes || []).map((c: any) => c.id);
    // READ → smart_quizzes - Retrieve published quizzes.
    const { data: quizzes, error: quizzesError } = await supabase
      .from("smart_quizzes")
      .select("id, subject, class_id, status")
      .eq("teacher_id", teacherId)
      .eq("status", "published");

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
    // Return empty analytics when no quizzes exist.
    if (!quizzes || quizzes.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          overall: {
            published_quizzes: 0,
            total_submissions: 0,
            overall_average_score: 0,
            participation_rate: 0,
          },
          strongest_subject: null,
          weakest_subject: null,
          subjects: [],
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    // Extract quiz identifiers.
    const quizIds = quizzes.map((q: any) => q.id);

    let pupils: any[] = [];

    if (classIds.length > 0) {
      // READ → pupils - Retrieve pupils from teacher classes.
      const { data: pupilsData, error: pupilsError } = await supabase
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

      pupils = pupilsData || [];
    }
    // READ → smart_quiz_attempts - Retrieve pupil quiz attempts.
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
    // Keep only completed submissions.
    const submittedAttempts = (attempts || []).filter(
      (a: any) => a.status === "submitted",
    );
    // Calculate total completed attempts.
    const totalSubmissions = submittedAttempts.length;
    // Calculate average score.
    const overallAverageScore =
      totalSubmissions > 0
        ? Math.round(
            submittedAttempts.reduce(
              (sum: number, a: any) => sum + Number(a.score_percent || 0),
              0,
            ) / totalSubmissions,
          )
        : 0;
    // Calculate expected participation.
    const totalPossibleSubmissions = quizzes.length * pupils.length;
    // Calculate participation percentage.
    const participationRate =
      totalPossibleSubmissions > 0
        ? Math.round((totalSubmissions / totalPossibleSubmissions) * 100)
        : 0;
    // Prepare subject performance summary.
    const subjectMap: Record<string, any> = {};
    // Group quizzes by subject.
    for (const quiz of quizzes) {
      if (!subjectMap[quiz.subject]) {
        subjectMap[quiz.subject] = {
          subject: quiz.subject,
          quizzes_count: 0,
          submissions_count: 0,
          total_score: 0,
        };
      }

      subjectMap[quiz.subject].quizzes_count += 1;
    }
    // Add scores to subject statistics.
    for (const attempt of submittedAttempts) {
      const quiz = quizzes.find((q: any) => q.id === attempt.quiz_id);
      if (!quiz) continue;

      subjectMap[quiz.subject].submissions_count += 1;
      subjectMap[quiz.subject].total_score += Number(attempt.score_percent || 0);
    }
    // Calculate average score per subject.
    const subjects = Object.values(subjectMap).map((item: any) => ({
      subject: item.subject,
      quizzes_count: item.quizzes_count,
      submissions_count: item.submissions_count,
      average_score:
        item.submissions_count > 0
          ? Math.round(item.total_score / item.submissions_count)
          : 0,
    }));
    // Rank subjects by performance.
    subjects.sort((a: any, b: any) => b.average_score - a.average_score);

    const subjectsWithSubmissions = subjects.filter(
      (s: any) => s.submissions_count > 0,
    );
    // Identify strongest and weakest subjects
    const strongestSubject =
      subjectsWithSubmissions.length > 0 ? subjectsWithSubmissions[0] : null;

    const weakestSubject =
      subjectsWithSubmissions.length > 0
        ? subjectsWithSubmissions[subjectsWithSubmissions.length - 1]
        : null;
    // Return analytics to Flutter.
    return new Response(
      JSON.stringify({
        success: true,
        overall: {
          published_quizzes: quizzes.length,
          total_submissions: totalSubmissions,
          overall_average_score: overallAverageScore,
          participation_rate: participationRate,
        },
        strongest_subject: strongestSubject,
        weakest_subject: weakestSubject,
        subjects,
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