import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "PUT, POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const url = new URL(req.url);
    const quizId = url.searchParams.get("quizId");

    if (!quizId) {
      return new Response(JSON.stringify({ error: "Missing quizId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { title, questions } = body || {};

    if (!title && !Array.isArray(questions)) {
      return new Response(JSON.stringify({
        error: "Please provide a title and/or questions array in JSON body.",
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: existingQuiz, error: fetchError } = await supabase
      .from("smart_quizzes")
      .select("status")
      .eq("id", quizId)
      .maybeSingle();

    if (fetchError || !existingQuiz) {
      return new Response(JSON.stringify({ error: "Quiz not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (existingQuiz.status !== "draft") {
      return new Response(JSON.stringify({
        error: "Only draft quizzes can be edited",
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (title) {
      const { error: updateTitleError } = await supabase
        .from("smart_quizzes")
        .update({ title })
        .eq("id", quizId);

      if (updateTitleError) {
        return new Response(JSON.stringify({
          error: "Failed to update quiz title",
          details: updateTitleError.message,
        }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    if (Array.isArray(questions)) {
      for (const question of questions) {
        const { id, question_text, correct_answer_text, explanation, options } = question;

        const { error: questionUpdateError } = await supabase
          .from("smart_quiz_questions")
          .update({
            question_text,
            correct_answer_text,
            explanation,
          })
          .eq("id", id);

        if (questionUpdateError) {
          return new Response(JSON.stringify({
            error: "Failed to update question",
            details: questionUpdateError.message,
          }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        if (Array.isArray(options)) {
          for (const opt of options) {
            const { error: optionUpdateError } = await supabase
              .from("smart_quiz_options")
              .update({
                option_text: opt.option_text,
                is_correct: opt.is_correct,
              })
              .eq("id", opt.id);

            if (optionUpdateError) {
              return new Response(JSON.stringify({
                error: "Failed to update option",
                details: optionUpdateError.message,
              }), {
                status: 500,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
              });
            }
          }
        }
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: "Draft quiz updated successfully",
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({
      error: "Internal server error",
      details: err instanceof Error ? err.message : String(err),
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});