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
      difficulty,
      question_type,
      number_of_questions,
      time_limit_minutes,
      available_from,
      deadline_at,
      leaderboard_size,
      title,
      subtopic,
      selected_subtopics,
      all_subtopics,
    } = body;

    if (
      !teacher_id ||
      !class_id ||
      !subject ||
      !topic ||
      !difficulty ||
      !question_type ||
      !number_of_questions ||
      !deadline_at
    ) {
      return new Response(
        JSON.stringify({ error: "Missing required fields for smart quiz" }),
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

    let subtopicsToUse: string[] = [];

    if (Array.isArray(selected_subtopics) && selected_subtopics.length > 0) {
      subtopicsToUse = selected_subtopics;
    } else if (subtopic) {
      subtopicsToUse = [subtopic];
    } else if (all_subtopics === true) {
      const { data: subtopicRows, error: subtopicError } = await supabase
        .from("curriculum_items")
        .select("subtopic")
        .eq("subject", subject)
        .eq("topic", topic)
        .eq("is_active", true);

      if (subtopicError) {
        throw new Error(subtopicError.message);
      }

      subtopicsToUse = [
        ...new Set((subtopicRows || []).map((row: any) => row.subtopic)),
      ].filter(Boolean);
    }

    if (subtopicsToUse.length === 0) {
      return new Response(
        JSON.stringify({ error: "Please select at least one subtopic" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { data: curriculumRows, error: curriculumError } = await supabase
      .from("curriculum_item_full")
      .select("*")
      .eq("subject", subject)
      .eq("topic", topic)
      .in("subtopic", subtopicsToUse);

    if (curriculumError) {
      throw new Error(curriculumError.message);
    }

    if (!curriculumRows || curriculumRows.length === 0) {
      return new Response(
        JSON.stringify({
          error: "No curriculum content found for the selected topic/subtopics",
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const curriculumText = curriculumRows
      .map((row: any) => {
        const objectives = Array.isArray(row.objectives)
          ? row.objectives.map((o: string) => `- ${o}`).join("\n")
          : "";

        const facts = Array.isArray(row.allowed_facts)
          ? row.allowed_facts.map((f: string) => `- ${f}`).join("\n")
          : "";

        return `
Subtopic: ${row.subtopic}
Objectives:
${objectives}

Allowed facts/rules:
${facts}
`;
      })
      .join("\n\n");

    const smartPrompt = `
You are creating a primary school quiz.

IMPORTANT RULES:
- Use ONLY the curriculum facts and objectives provided.
- Do not invent facts.
- Keep language simple and suitable for primary pupils.
- Return valid JSON only.
- Generate exactly ${number_of_questions} questions.
- Difficulty: ${difficulty}
- Question type requested: ${question_type}

Subject: ${subject}
Topic: ${topic}
Selected subtopics: ${subtopicsToUse.join(", ")}

Curriculum content:
${curriculumText}

Question type rules:
- If question_type is "mcq", each question must have exactly 4 options and exactly 1 correct option.
- If question_type is "true_false", each question must have 2 options: True and False, with exactly 1 correct option.
- If question_type is "fill_blank", options must be an empty array and correct_answer_text must contain the answer.
- If question_type is "mixed", use a reasonable mix of mcq, true_false and fill_blank.

Return this JSON structure:
{
  "questions": [
    {
      "order_index": 1,
      "question_text": "string",
      "question_type": "mcq | true_false | fill_blank",
      "difficulty": "${difficulty}",
      "marks": 1,
      "source_subtopic": "one selected subtopic",
      "correct_answer_text": "string",
      "explanation": "short explanation",
      "options": [
        { "order_index": 1, "option_text": "string", "is_correct": false }
      ]
    }
  ]
}
`;

    const parsed = await callOpenAIJson(smartPrompt);

    if (!Array.isArray(parsed.questions)) {
      throw new Error("AI did not return a questions array");
    }

    if (parsed.questions.length !== Number(number_of_questions)) {
      throw new Error("Generated question count does not match requested count");
    }

    const quizTitle =
      title || `${subject} - ${topic} - Smart Quiz`;

    const mainSubtopic =
      subtopicsToUse.length === 1 ? subtopicsToUse[0] : "Multiple subtopics";

    const { data: insertedQuiz, error: quizInsertError } = await supabase
      .from("smart_quizzes")
      .insert({
        teacher_id,
        class_id,
        title: quizTitle,
        subject,
        topic,
        subtopic: mainSubtopic,
        difficulty,
        question_type,
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
      throw new Error(quizInsertError.message);
    }

    const quizId = insertedQuiz.id;

    const subtopicRows = subtopicsToUse.map((s, index) => ({
      quiz_id: quizId,
      subject,
      topic,
      subtopic: s,
      order_index: index + 1,
    }));

    await supabase.from("smart_quiz_subtopics").insert(subtopicRows);

    for (const question of parsed.questions) {
      const qType = question.question_type || "mcq";

      const { data: insertedQuestion, error: questionInsertError } =
        await supabase
          .from("smart_quiz_questions")
          .insert({
            quiz_id: quizId,
            question_text: question.question_text,
            question_type: qType,
            difficulty: question.difficulty || difficulty,
            correct_answer_text: question.correct_answer_text || null,
            explanation: question.explanation || null,
            marks: question.marks || 1,
            order_index: question.order_index,
            source_subtopic:
              question.source_subtopic || subtopicsToUse[0],
          })
          .select()
          .single();

      if (questionInsertError) {
        throw new Error(questionInsertError.message);
      }

      if (qType === "mcq" || qType === "true_false") {
        if (!Array.isArray(question.options) || question.options.length === 0) {
          throw new Error("MCQ/True-False questions must have options");
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
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Smart quiz draft generated and saved successfully",
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