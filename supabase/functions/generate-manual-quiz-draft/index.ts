import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

async function callOpenAIJson(prompt: string) {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  const model = Deno.env.get("OPENAI_MODEL") || "gpt-4.1-mini";

  if (!apiKey) {
    throw new Error("Missing OPENAI_API_KEY secret");
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: prompt,
      text: {
        format: {
          type: "json_object",
        },
      },
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data?.error?.message || "OpenAI request failed");
  }

  const outputText =
    data.output_text ||
    data.output?.[0]?.content?.[0]?.text ||
    "";

  if (!outputText) {
    throw new Error("OpenAI returned empty response");
  }

  return JSON.parse(outputText);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();

    const {
      teacher_id,
      class_id,
      subject,
      topic,
      subtopic,
      difficulty,
      number_of_questions,
      time_limit_minutes,
      available_from,
      deadline_at,
      leaderboard_size,
      title,
      questions,
    } = body;

    if (
      !teacher_id ||
      !class_id ||
      !subject ||
      !topic ||
      !subtopic ||
      !difficulty ||
      !number_of_questions ||
      !deadline_at ||
      !Array.isArray(questions) ||
      questions.length === 0
    ) {
      return new Response(
        JSON.stringify({ error: "Missing required fields for manual quiz draft" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (questions.length !== Number(number_of_questions)) {
      return new Response(
        JSON.stringify({
          error: "Number of typed questions does not match number_of_questions",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: curriculum, error: curriculumError } = await supabase
      .from("curriculum_item_full")
      .select("*")
      .eq("subject", subject)
      .eq("topic", topic)
      .eq("subtopic", subtopic)
      .limit(1)
      .maybeSingle();

    if (curriculumError) {
      return new Response(
        JSON.stringify({
          error: "Failed to fetch curriculum content",
          details: curriculumError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!curriculum) {
      return new Response(
        JSON.stringify({
          error: "No curriculum content found for selected subject/topic/subtopic",
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const objectives = Array.isArray(curriculum.objectives)
      ? curriculum.objectives.map((o: string) => `- ${o}`).join("\n")
      : "";

    const facts = Array.isArray(curriculum.allowed_facts)
      ? curriculum.allowed_facts.map((f: string) => `- ${f}`).join("\n")
      : "";

    const manualPrompt = `
You are generating MCQ answers for a manually created primary school quiz.

IMPORTANT RULES:
- Keep the teacher's original question text exactly as written.
- Do NOT rewrite or simplify the question text.
- For each question, generate exactly 4 options.
- Exactly 1 option must be correct.
- Generate correct_answer_text and a short explanation.
- The explanation must be clear and suitable for primary pupils.
- Wrong options must be believable but clearly incorrect.
- Use simple child-friendly English.
- Return valid JSON only.

Subject: ${subject}
Topic: ${topic}
Subtopic: ${subtopic}
Difficulty: ${difficulty}

Learning objectives:
${objectives}

Allowed facts/rules:
${facts}

Teacher questions:
${questions.map((q: any, i: number) => `${i + 1}. ${q.question_text}`).join("\n")}

Return this JSON structure:
{
  "questions": [
    {
      "order_index": 1,
      "question_text": "same teacher question text",
      "question_type": "mcq",
      "difficulty": "${difficulty}",
      "marks": 1,
      "correct_answer_text": "string",
      "explanation": "string",
      "options": [
        { "order_index": 1, "option_text": "string", "is_correct": false },
        { "order_index": 2, "option_text": "string", "is_correct": true },
        { "order_index": 3, "option_text": "string", "is_correct": false },
        { "order_index": 4, "option_text": "string", "is_correct": false }
      ]
    }
  ]
}

Return exactly ${number_of_questions} questions.
`;

    const parsed = await callOpenAIJson(manualPrompt);

    if (!Array.isArray(parsed.questions)) {
      throw new Error("AI did not return a questions array");
    }

    if (parsed.questions.length !== Number(number_of_questions)) {
      throw new Error("Generated question count does not match requested count");
    }

    const quizTitle =
      title || `${subject} - ${topic} - ${subtopic} - Manual Quiz`;

    const { data: insertedQuiz, error: quizInsertError } = await supabase
      .from("smart_quizzes")
      .insert({
        teacher_id,
        class_id,
        title: quizTitle,
        subject,
        topic,
        subtopic,
        difficulty,
        question_type: "mcq",
        number_of_questions,
        time_limit_minutes: time_limit_minutes || null,
        available_from: available_from || new Date().toISOString(),
        deadline_at,
        leaderboard_size: leaderboard_size || 5,
        leaderboard_enabled: true,
        leaderboard_published: false,
        instant_result_enabled: true,
        reveal_answers_after_deadline: true,
        status: "draft",
        generated_by_ai: true,
      })
      .select()
      .single();

    if (quizInsertError) {
      return new Response(
        JSON.stringify({
          error: "Failed to insert manual quiz draft",
          details: quizInsertError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const quizId = insertedQuiz.id;

    await supabase.from("smart_quiz_subtopics").insert({
      quiz_id: quizId,
      subject,
      topic,
      subtopic,
      order_index: 1,
    });

    for (const question of parsed.questions) {
      const { data: insertedQuestion, error: questionInsertError } =
        await supabase
          .from("smart_quiz_questions")
          .insert({
            quiz_id: quizId,
            question_text: question.question_text,
            question_type: "mcq",
            difficulty: question.difficulty || difficulty,
            correct_answer_text: question.correct_answer_text || null,
            explanation: question.explanation || null,
            marks: question.marks || 1,
            order_index: question.order_index,
            source_subtopic: subtopic,
          })
          .select()
          .single();

      if (questionInsertError) {
        throw new Error(questionInsertError.message);
      }

      if (!Array.isArray(question.options) || question.options.length !== 4) {
        throw new Error("Each question must have exactly 4 options");
      }

      const optionsToInsert = question.options.map((option: any) => ({
        question_id: insertedQuestion.id,
        option_text: option.option_text,
        is_correct: option.is_correct,
        order_index: option.order_index,
      }));

      const { error: optionsInsertError } = await supabase
        .from("smart_quiz_options")
        .insert(optionsToInsert);

      if (optionsInsertError) {
        throw new Error(optionsInsertError.message);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Manual quiz draft generated and saved successfully",
        quiz_id: quizId,
        quiz_title: quizTitle,
        total_questions: parsed.questions.length,
        status: "draft",
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