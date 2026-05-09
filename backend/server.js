require("dotenv").config();

const express = require("express");
const cors = require("cors");
const OpenAI = require("openai");
const { createClient } = require("@supabase/supabase-js");

const app = express();
app.use(cors());
app.use(express.json());

// =========================
// ENV CHECKS
// =========================
const requiredEnv = [
  "OPENAI_API_KEY",
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
];

for (const key of requiredEnv) {
  if (!process.env[key]) {
    console.error(`Missing environment variable: ${key}`);
    process.exit(1);
  }
}

// =========================
// CLIENTS
// =========================
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// =========================
// HELPERS
// =========================
function normalizeAnswer(text) {
  return (text || "").trim().toLowerCase();
}

function calculateDurationSeconds(startedAt, submittedAt) {
  if (!startedAt || !submittedAt) return 0;
  const start = new Date(startedAt).getTime();
  const end = new Date(submittedAt).getTime();
  return Math.max(0, Math.floor((end - start) / 1000));
}

function shuffleArray(arr) {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function pickRandomExamples(examples, count = 4) {
  if (!Array.isArray(examples) || examples.length === 0) return [];
  if (examples.length <= count) return examples;
  return shuffleArray(examples).slice(0, count);
}
function distributeQuestionCounts(totalQuestions, subtopics) {
  const count = Array.isArray(subtopics) ? subtopics.length : 0;
  if (count === 0) return [];

  const base = Math.floor(totalQuestions / count);
  const remainder = totalQuestions % count;

  return subtopics.map((subtopic, index) => ({
    subtopic,
    question_count: base + (index < remainder ? 1 : 0),
  })).filter(item => item.question_count > 0);
}
// =========================
// SUBJECT-SPECIFIC PROMPT HELPERS
// =========================
const DEFAULT_GUIDANCE = ["MCQ", "True/False", "Fill in the blanks"];
const MATH_ONLY_GUIDANCE = ["MCQ", "True/False"];
const ENGLISH_ONLY_GUIDANCE = ["MCQ", "Fill in the blanks"];
const FRENCH_ONLY_GUIDANCE = ["MCQ", "Fill in the blanks"];
const HISTORY_ONLY_GUIDANCE = ["MCQ", "True/False", "Fill in the blanks"];
const GEOGRAPHY_ONLY_GUIDANCE = ["MCQ", "True/False", "Fill in the blanks"];

// Large Maths example bank.
// These are guidance examples only. The model must not copy them.
const MATH_EXAMPLES = {
  "Numbers::Word problems involving addition and subtraction": [
    "In a crowd, there are 113 426 children and 116 946 adults. How many people are there in all in the crowd?",
    "By how much is 113 215 greater than 73 230?",
    "By how much is 370 245 smaller than 375 254?",
    "When a number is reduced by 5 648, the result is 12 496. Find the number.",
    "After a discount of Rs 48, the price of a flower pot is Rs 235. What was the original price?"
  ],

  "Numbers::Word problems involving multiplication and division": [
    "Sarah is 12 years old. Her little brother Jonathan is 3 years old. How many times is Sarah as old as Jonathan?",
    "Richard and his 8 friends have 59 marbles each. How many marbles do they have in all?",
    "Lam sells candles in packs of 8. He has 5 042 candles to pack. How many packs does he get and how many candles are left?",
    "Bananas are sold in bunches of 6. A shopkeeper has 384 bananas. How many full bunches can be made?"
  ],

  "Numbers::Fraction word problems": [
    "A boy drank 3/8 of a bottle of juice in the morning and 1/4 in the afternoon. How much juice did he drink in all?",
    "A rope is 5 1/2 m long. If 2 3/4 m is cut off, how much rope is left?",
    "A class used 2/5 of a box of chalk on Monday and 1/5 on Tuesday. What fraction of the box remains?",
    "A cake was divided equally among 8 children. What fraction of the cake did each child get?"
  ],

  "Numbers::Decimal word problems": [
    "A bottle contains 1.75 L of juice. If 0.35 L is poured out, how much juice remains?",
    "A book costs Rs 125.75 and a pen costs Rs 24.50. Find the total cost.",
    "A runner covered 3.6 km in the morning and 4.25 km in the evening. How far did the runner travel altogether?",
    "A bag of rice weighs 12.5 kg. What is the mass of 4 such bags?"
  ],

  "Numbers::Percentage applications": [
    "Mary has 20 beads. She gives 40% to her friend Mala. How many beads does Mala get?",
    "A mobile phone costs Rs 12 000. In a sale, the price decreases by 14%. Find the new price of the mobile phone.",
    "Jason bought a book for Rs 240 and sold it for Rs 180. Calculate the percentage loss.",
    "A worker's salary increases from Rs 500 to Rs 575 per day. Calculate the percentage increase.",
    "In a park there are 480 animals, of which 120 are birds. Find the percentage of birds in the park.",
    "A shirt costs Rs 800. It is sold at 20% discount. Find the new price.",
    "A price increases by 25% from Rs 240. Find the new price.",
    "If 25% of a number is 50, find the number."
  ],

  "Numbers::Average": [
    "The average of four numbers is 63. Three of the numbers are 52, 60 and 65. Find the fourth number.",
    "The average of 6 numbers is 70. When a seventh number is added, the average increases to 71. Find the seventh number.",
    "Meera spends an average of Rs 40 per day during a school week. What is the total amount of money she spends in a school week?",
    "The average mass of 5 bags is 12 kg. Find the total mass."
  ],

  "Numbers::Ratio": [
    "Express the ratio 12:18 in simplest form.",
    "Find an equivalent ratio for 3:5.",
    "The ratio of red marbles to blue marbles is 2:3. If there are 30 marbles in all, how many are red?",
    "The ratio of boys to girls is 2:3 in a class of 50. Find the number of boys."
  ],

  "Numbers::Ratio applications": [
    "In a class of 30 pupils, the ratio of boys to girls was 3:2. After the holidays, 2 boys and 3 girls joined. What is the new ratio?",
    "The ratio of Dan’s age to Rita’s age is 3:5. If Dan is 6 years younger than Rita, find the sum of their ages.",
    "A sum of Rs 600 is shared in the ratio 2:3. Find each share.",
    "In a competition, for every 7 women there are 4 men. If there are 12 more women than men, find the total number of participants."
  ],

  "Numbers::Proportion": [
    "Bananas are sold at 4 for Rs 10. Find the cost of 12 bananas.",
    "20 men build a house in 6 days. How long will it take 30 men to build the same house?",
    "If 5 pens cost Rs 45, how much will 8 pens cost at the same rate?",
    "A car travels 180 km in 3 hours. How far will it travel in 5 hours at the same speed?"
  ],

  "Measure::Perimeter": [
    "The perimeter of a rectangular photo frame is 96 cm. Its width is 18 cm. What is its length?",
    "A rectangular playground is 75 m long and 43 m wide. Find its perimeter.",
    "The length of a rectangle is three times its width. If the perimeter is 128 cm, find its length and width.",
    "A square lawn has side 5 m 20 cm. What is its perimeter?"
  ],

  "Measure::Capacity": [
    "How much oil is left in a barrel containing 14 L 78 cL if 7 L 25 cL is taken out?",
    "2420 mL of oil is used to fill 4 bottles of equal capacity. How much oil does one bottle hold?",
    "A baker uses 2 L 300 mL of milk on Monday, 3.5 L on Tuesday and 2.75 L on Wednesday. How much milk is used in all?"
  ],

  "Measure::Mass": [
    "A packet of flour has a mass of 5 kg 400 g. What is the total mass of 9 such packets?",
    "Twelve copies of a dictionary weigh 21 kg 600 g. What is the mass of one such dictionary?",
    "A ship weighs 8 t 500 kg. It is 6 t 750 kg heavier than a ferry boat. Find the mass of the ferry boat."
  ],

  "Measure::Money": [
    "Two pens and three rulers cost Rs 70.50. A pen costs Rs 22.50. Find the cost of a ruler.",
    "Manisha and Karishma each bought a T-shirt for Rs 385. If they gave the cashier a Rs 1 000 note, how much change did they get back?",
    "A trader sold an air conditioner for Rs 42 500. He made a profit of Rs 3 825. How much did he buy it for?",
    "Apples cost 3 for Rs 20. Maisy has Rs 240. How many apples can she buy?",
    "For a day’s work, Ah-Kim is paid Rs 375. He works 5 days per week. How much does he earn in 8 weeks?"
  ],

  "Measure::Foreign currency": [
    "David received $400. Calculate how many rupees he will get if $1 = Rs 35.",
    "Marvin changes £600 into rupees. How much money in rupees will he get if £1 = Rs 47?"
  ],

  "Measure::Time": [
    "A film starts at 13 30 and ends at 15 45. What is the duration of the film?",
    "Find the number of minutes between 09 30 and 13 35 on the same day.",
    "Convert 2 hours 30 minutes into minutes.",
    "Add 3 h 35 min and 2 h 45 min.",
    "Subtract 5 h 20 min from 8 h 10 min.",
    "Maya is 10 years 7 months old. Aliyah is twice as old as Maya. How old is Aliyah?"
  ],

  "Measure::Calendar": [
    "If today is Monday 12th May, what date and day will it be in 15 days?",
    "Calculate the number of days between two given dates.",
    "February has 29 days in a leap year and 28 days in a common year. Use this fact in a question."
  ],

  "Measure::GMT": [
    "A football match in London starts at 15 00 GMT. At what time can it be watched live in Mauritius if Mauritian time = GMT + 4 h?",
    "An award ceremony starts at 18 00 in Mumbai. What is the time in Mauritius if Mumbai time = Mauritian time + 1 h 30 min?"
  ],

  "Measure::Area": [
    "The area of a square is 144 cm². Find its side length.",
    "The area of a rectangular garden is 240 m². Its length is 20 m. Find its perimeter.",
    "A rectangular path measures 5 m by 1.5 m. Find its area.",
    "A rectangle has length 12 cm and area 84 cm². Find its width."
  ],

  "Measure::Surface area": [
    "Find total surface area of a cube.",
    "Find the area of one face when total surface area of a cube is given.",
    "Find total surface area of a cuboid."
  ],

  "Measure::Tiling": [
    "The floor of a room, 6 m long and 5 m wide, is covered with square tiles of edge 20 cm. How many tiles are required?",
    "A wall, 3 m 50 cm long and 2 m 40 cm wide, is covered with rectangular tiles 25 cm by 20 cm. How many such tiles are needed?"
  ],

  "Measure::Volume": [
    "Find the volume of a cuboid 12 cm long, 10 cm wide and 8 cm high.",
    "The volume of a rectangular metal block, 40 cm long and 30 cm wide, is 9 600 cm³. Find the height.",
    "How many 3-cm cubes are needed to make a cube of edge 12 cm?",
    "A cube of edge 5 cm is put inside a cubical box of edge 8 cm. Calculate the volume of space left unoccupied.",
    "A rectangular tank, 8 m long and 5 m wide, was 25% filled with water. When another 70 m³ of water was poured into the tank, the tank became 60% filled. Find the height of the tank."
  ],

  "Measure::Speed": [
    "Calculate speed if distance and time are given.",
    "Calculate time if distance and speed are given.",
    "Calculate distance if speed and time are given."
  ]
};

function getGuidanceForSubject(subject) {
  const s = (subject || "").toLowerCase();

  if (s === "mathematics") {
    return MATH_ONLY_GUIDANCE;
  }

  if (s === "english") {
    return ENGLISH_ONLY_GUIDANCE;
  }

  if (s === "french") {
    return FRENCH_ONLY_GUIDANCE;
  }

  if (s === "history") {
    return HISTORY_ONLY_GUIDANCE;
  }

  if (s === "geography") {
    return GEOGRAPHY_ONLY_GUIDANCE;
  }

  return DEFAULT_GUIDANCE;
}

function getExamplesForPrompt(subject, topic, subtopic) {
  if ((subject || "").toLowerCase() !== "mathematics") {
    return [];
  }

  const key = `${topic}::${subtopic}`;
  return MATH_EXAMPLES[key] || [];
}

function buildExamplesText(subject, topic, subtopic) {
  const examples = getExamplesForPrompt(subject, topic, subtopic);
  const selected = pickRandomExamples(examples, 4);

  if (!selected.length) {
    return "No explicit examples provided for this subtopic. Generate questions strictly from the objectives, allowed facts, and Grade 6 level.";
  }

  return selected.map((ex, index) => `${index + 1}. ${ex}`).join("\n");
}
function normalizeSelectedSubtopics(body) {
  if (Array.isArray(body.selected_subtopics) && body.selected_subtopics.length > 0) {
    return body.selected_subtopics;
  }

  if (body.subtopic && typeof body.subtopic === "string") {
    return [body.subtopic];
  }

  return [];
}
function getQuestionTypeInstruction(subject, questionType) {
  const s = (subject || "").toLowerCase();
  const q = (questionType || "").toLowerCase();

  if (s === "mathematics") {
    if (q === "mcq") {
      return "Generate only MCQ questions. Each MCQ must have exactly 4 options and exactly 1 correct answer.";
    }
    if (q === "true_false") {
      return "Generate only True/False questions. Each question must have exactly 2 options: True and False.";
    }
    if (q === "mixed") {
      return "Generate a balanced mix of MCQ and True/False questions only. Do not generate fill in the blanks for Mathematics.";
    }
    return "Generate only MCQ and/or True/False questions for Mathematics. Do not generate fill in the blanks.";
  }

  if (q === "mcq") {
    return "Generate only MCQ questions. Each MCQ must have exactly 4 options and exactly 1 correct answer.";
  }
  if (q === "true_false") {
    return "Generate only True/False questions. Each question must have exactly 2 options: True and False.";
  }
  if (q === "fill_blank") {
    return "Generate only Fill in the Blank questions. Do not include options.";
  }
  if (q === "mixed") {
    return "Generate a balanced mix of MCQ, True/False, and Fill in the Blank questions.";
  }

  return "Follow the requested question type strictly.";
}
function getEnglishSpecificInstruction(subject, topic, subtopic) {
  if ((subject || "").toLowerCase() !== "english") return "";

  return `
ENGLISH-SPECIFIC RULES:
- Generate sentence-based grammar exercises only.
- Do not generate essays, paragraphs, stories, comprehension passages, dialogues, or open-ended writing tasks.
- Use only the selected topic and subtopic.
- For Fill in the blanks:
  - generate one clear sentence per question
  - leave exactly one blank where possible
  - the missing answer must match the selected subtopic
- For MCQ:
  - generate one clear sentence per question
  - provide exactly 4 options
  - only one option must be correct
- Keep vocabulary simple and suitable for primary pupils.
- Do not mix several grammar lessons in one question unless the selected subtopic clearly requires it.
- For punctuation subtopics, generate sentence correction or choice questions focused only on punctuation marks.
- For sentence structure subtopics, generate sentence-completion or sentence-identification items only.
`;
}
function getFrenchSpecificInstruction(subject, topic, subtopic) {
  if ((subject || "").toLowerCase() !== "french") return "";

  return `
FRENCH-SPECIFIC RULES:
- Génère uniquement des exercices de grammaire en phrases courtes.
- Ne génère pas de rédaction, de paragraphe, de compréhension écrite, de dialogue ou de texte long.
- Utilise uniquement le thème et le sous-thème choisis.
- Pour Fill in the blanks:
  - génère une phrase courte par question
  - laisse un seul blanc si possible
  - le mot manquant doit correspondre exactement au sous-thème choisi
- Pour MCQ:
  - génère une phrase courte par question
  - donne exactement 4 choix
  - une seule réponse doit être correcte
- Utilise un français simple adapté aux élèves du primaire.
- Ne mélange pas plusieurs notions grammaticales sauf si le sous-thème l’exige clairement.
- Pour la conjugaison, génère des phrases avec le verbe à compléter ou à choisir.
- Pour les types de phrases, génère des phrases simples à identifier ou à compléter.
- Pour l’orthographe et la phonétique, génère des phrases très courtes ciblant uniquement la notion choisie.
`;
}
function getHistorySpecificInstruction(subject, topic, subtopic) {
  if ((subject || "").toLowerCase() !== "history") return "";

  return `
HISTORY-SPECIFIC RULES:
- Use ONLY the facts provided for the selected subtopic.
- Do NOT use any outside historical knowledge.
- Do NOT mix facts from other subtopics or topics.
- Keep questions fact-based, simple, and suitable for primary pupils.
- Use names, dates, places, people, events, causes and effects ONLY if they are listed in the subtopic facts.
- Do not generate long descriptive passages.
- Keep each question short and clear.
- For Fill in the blanks:
  - use one short sentence where possible
  - use only a fact stated in the selected subtopic
- For MCQ:
  - use exactly 4 options
  - only one option must be correct
  - wrong options should be believable but must not introduce facts outside the selected subtopic
- For True/False:
  - statements must come only from the selected subtopic facts
  - do not invent extra details
`;
}
function getGeographySpecificInstruction(subject, topic, subtopic) {
  if ((subject || "").toLowerCase() !== "geography") return "";

  return `
GEOGRAPHY-SPECIFIC RULES:
- Use ONLY the facts provided for the selected subtopic.
- Do NOT use any outside geographical knowledge.
- Do NOT mix facts from other subtopics or topics.
- Keep questions short, factual, and suitable for primary pupils.
- Use names, places, definitions, causes, effects, examples, percentages, dates, directions, uses and features ONLY if they are listed in the selected subtopic facts.
- Do not generate long descriptive passages.
- For Fill in the blanks:
  - use one short sentence where possible
  - use only a fact stated in the selected subtopic
- For MCQ:
  - use exactly 4 options
  - only one option must be correct
  - wrong options should be believable but must not introduce facts outside the selected subtopic
- For True/False:
  - statements must come only from the selected subtopic facts
  - do not invent extra details
`;
}
function getSubtopicSpecificInstruction(subject, topic, subtopic, numberOfQuestions) {
  if ((subject || "").toLowerCase() !== "mathematics") return "";

  const key = `${topic}::${subtopic}`;
  const minControlledQuestions = Math.max(1, Number(numberOfQuestions || 5) - 1);

  const rules = {
    "Numbers::Percentage applications": `
SUBTOPIC-SPECIFIC RULES FOR PERCENTAGE APPLICATIONS:
- Every question must require an actual percentage calculation.
- Acceptable forms are:
  1. percentage of a quantity
  2. express a quantity as a percentage
  3. percentage increase
  4. percentage decrease
  5. percentage profit
  6. percentage loss
  7. reverse percentage problems
- If profit or loss is used, the question must ask for percentage profit or percentage loss.
- Do not generate plain profit or plain loss amount questions.
- At least ${minControlledQuestions} questions must directly involve percentage computation.
`,

    "Numbers::Ratio": `
SUBTOPIC-SPECIFIC RULES FOR RATIO:
- Every question must directly involve ratio.
- Acceptable forms are:
  1. simplify a ratio
  2. find equivalent ratios
  3. compare quantities using ratio
- Do not turn ratio questions into ordinary fraction-only or division-only questions.
`,

    "Numbers::Ratio applications": `
SUBTOPIC-SPECIFIC RULES FOR RATIO APPLICATIONS:
- Questions must involve practical use of ratio.
- Acceptable forms are:
  1. splitting a quantity in a ratio
  2. ratio change after values are added or removed
  3. ratio involving differences
  4. age ratio problems
- At least ${minControlledQuestions} questions must involve real-life ratio application.
`,

    "Numbers::Proportion": `
SUBTOPIC-SPECIFIC RULES FOR PROPORTION:
- Every question must involve direct or indirect proportion.
- Acceptable forms are:
  1. cost and quantity
  2. workers and time
  3. repeated rate situations
- Do not generate plain multiplication questions unless proportion is essential.
`,

    "Numbers::Average": `
SUBTOPIC-SPECIFIC RULES FOR AVERAGE:
- Questions must involve average directly.
- Acceptable forms are:
  1. find average
  2. find total from average
  3. find missing value from average
  4. reverse average contexts
- At least ${minControlledQuestions} questions must require actual average reasoning.
`,

    "Numbers::Fraction word problems": `
SUBTOPIC-SPECIFIC RULES FOR FRACTION WORD PROBLEMS:
- Questions must be real word problems using fractions.
- Acceptable forms are:
  1. sharing
  2. combining fractional amounts
  3. comparing fractions
  4. finding what remains
- Do not generate pure symbolic fraction calculations without context.
`,

    "Numbers::Decimal word problems": `
SUBTOPIC-SPECIFIC RULES FOR DECIMAL WORD PROBLEMS:
- Questions must be real word problems using decimals.
- Acceptable forms are:
  1. money
  2. measurement
  3. capacity
  4. mass
  5. shopping totals
- Do not generate pure decimal calculations without context.
`,

    "Measure::Time": `
SUBTOPIC-SPECIFIC RULES FOR TIME:
- Questions must involve time calculation directly.
- Acceptable forms are:
  1. duration
  2. addition/subtraction of time
  3. conversion of time units
  4. days/hours
  5. years/months
- Do not generate only simple clock-reading questions.
- At least ${minControlledQuestions} questions must require time calculation.
`,

    "Measure::Money": `
SUBTOPIC-SPECIFIC RULES FOR MONEY:
- Questions must involve money reasoning directly.
- Acceptable forms are:
  1. total cost
  2. change
  3. comparing prices
  4. wages
  5. profit/loss
- Do not generate generic number problems with Rs added unless the money context matters.
`,

    "Measure::Volume": `
SUBTOPIC-SPECIFIC RULES FOR VOLUME:
- Questions must involve volume directly.
- Acceptable forms are:
  1. volume of cube
  2. volume of cuboid
  3. missing dimension from volume
  4. fitting cubes
  5. empty space left
  6. relation between capacity and volume
- Do not confuse area and volume.
- Do not generate surface area questions unless surface area is the selected subtopic.
- At least ${minControlledQuestions} questions must require actual volume reasoning.
`,
  };

  return rules[key] || "";
}

function buildPrompt(payload, curriculum) {
  const subject = payload.subject || "";
  const topic = payload.topic || "";
  const subtopic = payload.subtopic || "";

  const objectives = Array.isArray(curriculum.objectives)
    ? curriculum.objectives.map((o) => `- ${o}`).join("\n")
    : "";

  const allowedFacts = Array.isArray(curriculum.allowed_facts)
    ? curriculum.allowed_facts.map((f) => `- ${f}`).join("\n")
    : "";

  const forbiddenScope = Array.isArray(curriculum.forbidden_scope)
    ? curriculum.forbidden_scope.map((f) => `- ${f}`).join("\n")
    : "";

  const dbGuidance = Array.isArray(curriculum.question_guidance)
    ? curriculum.question_guidance.map((g) => `- ${g}`).join("\n")
    : "";

  const subjectGuidance = getGuidanceForSubject(subject)
    .map((g) => `- ${g}`)
    .join("\n");

  const examplesText = buildExamplesText(subject, topic, subtopic);
  const questionTypeInstruction = getQuestionTypeInstruction(
    subject,
    payload.question_type
  );

  const subtopicSpecificInstruction = getSubtopicSpecificInstruction(
    subject,
    topic,
    subtopic,
    payload.number_of_questions
  );
  const englishSpecificInstruction = getEnglishSpecificInstruction(
    subject,
    topic,
    subtopic
  );
  const frenchSpecificInstruction = getFrenchSpecificInstruction(
    subject,
    topic,
    subtopic
  );
  const historySpecificInstruction = getHistorySpecificInstruction(
    subject,
    topic,
    subtopic
  );
  const geographySpecificInstruction = getGeographySpecificInstruction(
    subject,
    topic,
    subtopic
  );
  const mathsExtraRules =
    subject.toLowerCase() === "mathematics"
      ? `
MATHEMATICS-SPECIFIC RULES:
1. Questions must match Grade 6 level and PSAC-style classroom expectations.
2. Use the examples only to understand the concept, wording level, and difficulty.
3. Do not copy the examples.
4. Do not reuse the same numbers from the examples unless unavoidable.
5. Do not simply change names while keeping the same structure.
6. Generate new questions that test the same mathematical concept.
7. For word problems, use realistic school-level contexts such as money, time, shopping, age, measurement, sharing, comparison, distance, and simple daily-life situations.
8. Keep the wording clear and age-appropriate.
9. Difficulty should follow the requested level:
   - easy = direct, one clear step
   - medium = one or two steps, some thinking
   - hard = multi-step, reverse reasoning, or hidden operation
10. For Mathematics, never generate Fill in the Blank questions.
11. For True/False in Mathematics, prefer thinking-based statements rather than very obvious facts.
`
      : "";

  return `
Generate a school quiz.

RULES:
- Generate exactly ${payload.number_of_questions} questions.
- Return valid JSON only.
- Use simple, child-friendly English.
- Do not generate duplicate questions.
- ${questionTypeInstruction}

${mathsExtraRules}
${englishSpecificInstruction}
${frenchSpecificInstruction}
${historySpecificInstruction}
${geographySpecificInstruction}
${subtopicSpecificInstruction}

Subject: ${subject}
Topic: ${topic}
Subtopic: ${subtopic}
Difficulty: ${payload.difficulty}
Question type: ${payload.question_type}

Learning objectives:
${objectives}

Allowed facts / rules:
${allowedFacts}

Forbidden scope:
${forbiddenScope}

Database question guidance:
${dbGuidance}

Subject question guidance:
${subjectGuidance}

Reference examples (do not copy):
${examplesText}

OUTPUT JSON STRUCTURE:
{
  "title": "string",
  "subject": "string",
  "topic": "string",
  "subtopic": "string",
  "difficulty": "easy | medium | hard | mixed",
  "question_type": "mcq | true_false | fill_blank | mixed",
  "questions": [
    {
      "order_index": 1,
      "question_text": "string",
      "question_type": "mcq | true_false | fill_blank",
      "difficulty": "easy | medium | hard",
      "marks": 1,
      "correct_answer_text": "string",
      "explanation": "string",
      "options": [
        {
          "order_index": 1,
          "option_text": "string",
          "is_correct": false
        }
      ]
    }
  ]
}

OUTPUT RULES:
1. For MCQ:
   - include exactly 4 options
   - exactly 1 correct option
2. For True/False:
   - include exactly 2 options: True and False
3. For Fill in the Blank:
   - do not include options
4. Return JSON only.
`;
}

// =========================
// BASIC ROUTES
// =========================
app.get("/", (req, res) => {
  res.json({
    message: "Smart EduQuiz backend is running",
  });
});

// =========================
// GENERATE SMART QUIZ
// =========================
app.post("/generate-smart-quiz", async (req, res) => {
  try {
    const {
      teacher_id,
      class_id,
      subject,
      topic,
      //subtopic,
      difficulty,
      question_type,
      number_of_questions,
      time_limit_minutes,
      available_from,
      deadline_at,
      leaderboard_size,
      title,
    } = req.body;

    const selectedSubtopics = normalizeSelectedSubtopics(req.body);

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
      return res.status(400).json({
        error: "Missing required fields",
      });
    }
    if (
      (subject || "").toLowerCase() === "mathematics" &&
      !["mcq", "true_false", "mixed"].includes((question_type || "").toLowerCase())
    ) {
      return res.status(400).json({
        error: "For Mathematics, question_type must be mcq, true_false, or mixed only.",
      });
    }
    if (
      (subject || "").toLowerCase() === "english" &&
      !["mcq", "fill_blank"].includes((question_type || "").toLowerCase())
    ) {
      return res.status(400).json({
        error: "For English, question_type must be mcq or fill_blank only.",
      });
    }
    if (
      (subject || "").toLowerCase() === "french" &&
      !["mcq", "fill_blank"].includes((question_type || "").toLowerCase())
    ) {
      return res.status(400).json({
        error: "For French, question_type must be mcq or fill_blank only.",
      });
    }
    if (
      (subject || "").toLowerCase() === "history" &&
      !["mcq", "true_false", "fill_blank", "mixed"].includes((question_type || "").toLowerCase())
    ) {
      return res.status(400).json({
        error: "For History, question_type must be mcq, true_false, fill_blank, or mixed.",
      });
    }
    if (
      (subject || "").toLowerCase() === "geography" &&
      !["mcq", "true_false", "fill_blank", "mixed"].includes((question_type || "").toLowerCase())
    ) {
      return res.status(400).json({
        error: "For Geography, question_type must be mcq, true_false, fill_blank, or mixed.",
      });
    }
    
    let finalSelectedSubtopics = [...selectedSubtopics];

    if (req.body.all_subtopics === true) {
      const { data: allSubtopicRows, error: allSubtopicsError } = await supabase
        .from("curriculum_items")
        .select("subtopic")
        .eq("subject", subject)
        .eq("topic", topic)
        .eq("is_active", true)
        .order("subtopic", { ascending: true });

      if (allSubtopicsError) {
        return res.status(500).json({
          error: "Failed to fetch all subtopics for topic",
          details: allSubtopicsError.message,
        });
      }

      finalSelectedSubtopics = [...new Set((allSubtopicRows || []).map(row => row.subtopic))];
    } else {
      finalSelectedSubtopics = [...new Set(finalSelectedSubtopics)];
    }

    if (!finalSelectedSubtopics.length) {
      return res.status(400).json({
        error: "Please select at least one subtopic.",
      });
    }

    const distributed = distributeQuestionCounts(
      Number(number_of_questions),
      finalSelectedSubtopics
    );

    const generatedQuestions = [];

    for (const item of distributed) {
      const { data: curriculum, error: curriculumError } = await supabase
        .from("curriculum_item_full")
        .select("*")
        .eq("subject", subject)
        .eq("topic", topic)
        .eq("subtopic", item.subtopic)
        .limit(1)
        .maybeSingle();

      if (curriculumError) {
        return res.status(500).json({
          error: "Failed to fetch curriculum content",
          details: curriculumError.message,
        });
      }

      if (!curriculum) {
        return res.status(404).json({
          error: `No curriculum content found for subtopic: ${item.subtopic}`,
        });
      }

      const payloadForSubtopic = {
        ...req.body,
        subtopic: item.subtopic,
        number_of_questions: item.question_count,
      };

      const prompt = buildPrompt(payloadForSubtopic, curriculum);

      const response = await openai.responses.create({
        model: "gpt-5.4-mini",
        input: prompt,
      });

      const outputText = response.output_text;

      if (!outputText) {
        return res.status(500).json({
          error: "Model returned empty response",
        });
      }

      let parsed;
      try {
        parsed = JSON.parse(outputText);
      } catch (parseError) {
        return res.status(500).json({
          error: "Failed to parse AI JSON response",
          raw_output: outputText,
        });
      }
      

      const questionsWithSource = parsed.questions.map((q) => ({
        ...q,
        source_subtopic: item.subtopic,
      }));

      generatedQuestions.push(...questionsWithSource);
    }
    if (!Array.isArray(generatedQuestions) || generatedQuestions.length === 0) {
      return res.status(500).json({
        error: "No questions were generated",
      });
    }

    if (generatedQuestions.length < Number(number_of_questions)) {
      return res.status(500).json({
        error: "Generated fewer questions than requested",
        generated_count: generatedQuestions.length,
        requested_count: Number(number_of_questions),
      });
    }

    if (generatedQuestions.length > Number(number_of_questions)) {
      generatedQuestions.splice(Number(number_of_questions));
    }

    generatedQuestions.forEach((q, index) => {
      q.order_index = index + 1;
    });

    const quizTitle =
      title ||
      `${subject} - ${topic} - ${finalSelectedSubtopics.length === 1 ? finalSelectedSubtopics[0] : "Multiple subtopics"}`;

    const { data: insertedQuiz, error: quizInsertError } = await supabase
      .from("smart_quizzes")
      .insert({
        teacher_id,
        class_id,
        title: quizTitle,
        subject,
        topic,
        subtopic: finalSelectedSubtopics.length === 1 ? finalSelectedSubtopics[0] : 'Multiple subtopics',
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
      return res.status(500).json({
        error: "Failed to insert smart quiz",
        details: quizInsertError.message,
      });
    }

    const quizId = insertedQuiz.id;
    const subtopicRows = finalSelectedSubtopics.map((sub, index) => ({
      quiz_id: quizId,
      subject,
      topic,
      subtopic: sub,
      order_index: index + 1,
    }));

    const { error: subtopicsInsertError } = await supabase
      .from("smart_quiz_subtopics")
      .insert(subtopicRows);

    if (subtopicsInsertError) {
      return res.status(500).json({
        error: "Failed to save quiz subtopics",
        details: subtopicsInsertError.message,
      });
    }

    for (const question of generatedQuestions) {
      const { data: insertedQuestion, error: questionInsertError } = await supabase
        .from("smart_quiz_questions")
        .insert({
          quiz_id: quizId,
          question_text: question.question_text,
          question_type: question.question_type,
          difficulty: question.difficulty,
          correct_answer_text: question.correct_answer_text || null,
          explanation: question.explanation || null,
          marks: question.marks || 1,
          order_index: question.order_index,
          source_subtopic: question.source_subtopic || null,
        })
        .select()
        .single();

      if (questionInsertError) {
        return res.status(500).json({
          error: "Failed to insert smart quiz question",
          details: questionInsertError.message,
        });
      }

      if (
        Array.isArray(question.options) &&
        (question.question_type === "mcq" || question.question_type === "true_false")
      ) {
        const optionsToInsert = question.options.map((option) => ({
          question_id: insertedQuestion.id,
          option_text: option.option_text,
          is_correct: option.is_correct,
          order_index: option.order_index,
        }));

        const { error: optionsInsertError } = await supabase
          .from("smart_quiz_options")
          .insert(optionsToInsert);

        if (optionsInsertError) {
          return res.status(500).json({
            error: "Failed to insert smart quiz options",
            details: optionsInsertError.message,
          });
        }
      }
    }
    return res.json({
      success: true,
      message: "Draft quiz generated and saved successfully",
      quiz_id: quizId,
      quiz_title: quizTitle,
      total_questions: generatedQuestions.length,
      selected_subtopics: finalSelectedSubtopics,
      status: "draft",
    });

  } catch (error) {
    console.error("Generate smart quiz error:", error);
    return res.status(500).json({
      error: "Internal server error",
      details: error.message,
    });
  }
});
// =========================
// GENERATE MANUAL QUIZ DRAFT
// =========================
app.post("/generate-manual-quiz-draft", async (req, res) => {
  try {
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
    } = req.body;

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
      return res.status(400).json({
        error: "Missing required fields for manual quiz draft",
      });
    }

    if (questions.length !== Number(number_of_questions)) {
      return res.status(400).json({
        error: "Number of typed questions does not match number_of_questions",
      });
    }

    const { data: curriculum, error: curriculumError } = await supabase
      .from("curriculum_item_full")
      .select("*")
      .eq("subject", subject)
      .eq("topic", topic)
      .eq("subtopic", subtopic)
      .limit(1)
      .maybeSingle();

    if (curriculumError) {
      return res.status(500).json({
        error: "Failed to fetch curriculum content",
        details: curriculumError.message,
      });
    }

    if (!curriculum) {
      return res.status(404).json({
        error: "No curriculum content found for selected subject/topic/subtopic",
      });
    }

    const manualPrompt = `
You are generating MCQ answers for a manually created school quiz.

IMPORTANT RULES:
- Keep the teacher's original question text exactly as written.
- Do NOT rewrite or simplify the question text.
- For each question, generate:
  1. exactly 4 options
  2. exactly 1 correct option
  3. correct_answer_text
  4. explanation
- The explanation must be short, clear, and suitable for primary pupils.
- Wrong options must be believable but clearly incorrect.
- Keep everything aligned with the selected curriculum area.
- Use simple child-friendly English.
- Return valid JSON only.

Subject: ${subject}
Topic: ${topic}
Subtopic: ${subtopic}
Difficulty: ${difficulty}

Learning objectives:
${Array.isArray(curriculum.objectives) ? curriculum.objectives.map((o) => `- ${o}`).join("\n") : ""}

Allowed facts / rules:
${Array.isArray(curriculum.allowed_facts) ? curriculum.allowed_facts.map((f) => `- ${f}`).join("\n") : ""}

Teacher questions:
${questions.map((q, i) => `${i + 1}. ${q.question_text}`).join("\n")}

OUTPUT JSON STRUCTURE:
{
  "questions": [
    {
      "order_index": 1,
      "question_text": "string",
      "question_type": "mcq",
      "difficulty": "easy | medium | hard",
      "marks": 1,
      "correct_answer_text": "string",
      "explanation": "string",
      "options": [
        {
          "order_index": 1,
          "option_text": "string",
          "is_correct": false
        }
      ]
    }
  ]
}

OUTPUT RULES:
- Return exactly ${number_of_questions} questions
- Use the same question_text as the teacher provided
- Each question must have exactly 4 options
- Exactly 1 option must be correct
- Return JSON only
`;

    const response = await openai.responses.create({
      model: "gpt-5.4-mini",
      input: manualPrompt,
    });

    const outputText = response.output_text;

    if (!outputText) {
      return res.status(500).json({
        error: "Model returned empty response",
      });
    }

    let parsed;
    try {
      parsed = JSON.parse(outputText);
    } catch (parseError) {
      return res.status(500).json({
        error: "Failed to parse AI JSON response",
        raw_output: outputText,
      });
    }

    if (!Array.isArray(parsed.questions) || parsed.questions.length === 0) {
      return res.status(500).json({
        error: "AI did not return valid questions",
      });
    }

    if (parsed.questions.length !== Number(number_of_questions)) {
      return res.status(500).json({
        error: "Generated question count does not match requested count",
      });
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
      return res.status(500).json({
        error: "Failed to insert manual quiz draft",
        details: quizInsertError.message,
      });
    }

    const quizId = insertedQuiz.id;

    const { error: subtopicInsertError } = await supabase
      .from("smart_quiz_subtopics")
      .insert({
        quiz_id: quizId,
        subject,
        topic,
        subtopic,
        order_index: 1,
      });

    if (subtopicInsertError) {
      return res.status(500).json({
        error: "Failed to save manual quiz subtopic",
        details: subtopicInsertError.message,
      });
    }

    for (const question of parsed.questions) {
      const { data: insertedQuestion, error: questionInsertError } = await supabase
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
        return res.status(500).json({
          error: "Failed to insert manual quiz question",
          details: questionInsertError.message,
        });
      }

      if (!Array.isArray(question.options) || question.options.length !== 4) {
        return res.status(500).json({
          error: "Each manual quiz question must have exactly 4 options",
        });
      }

      const optionsToInsert = question.options.map((option) => ({
        question_id: insertedQuestion.id,
        option_text: option.option_text,
        is_correct: option.is_correct,
        order_index: option.order_index,
      }));

      const { error: optionsInsertError } = await supabase
        .from("smart_quiz_options")
        .insert(optionsToInsert);

      if (optionsInsertError) {
        return res.status(500).json({
          error: "Failed to insert manual quiz options",
          details: optionsInsertError.message,
        });
      }
    }

    return res.json({
      success: true,
      message: "Manual quiz draft generated and saved successfully",
      quiz_id: quizId,
      quiz_title: quizTitle,
      total_questions: parsed.questions.length,
      status: "draft",
    });
  } catch (error) {
    console.error("Generate manual quiz draft error:", error);
    return res.status(500).json({
      error: "Internal server error",
      details: error.message,
    });
  }
});
// =========================
// FETCH CURRICULUM SUBJECTS
// =========================
app.get("/curriculum/subjects", async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("curriculum_items")
      .select("subject")
      .eq("is_active", true);

    if (error) {
      return res.status(500).json({
        error: "Failed to fetch curriculum subjects",
        details: error.message,
      });
    }

    const subjects = [...new Set((data || []).map((row) => row.subject))]
      .filter(Boolean)
      .sort();

    return res.json({
      success: true,
      subjects,
    });
  } catch (err) {
    console.error("Fetch curriculum subjects error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});

// =========================
// FETCH CURRICULUM TOPICS
// =========================
app.get("/curriculum/topics", async (req, res) => {
  try {
    const { subject } = req.query;

    if (!subject) {
      return res.status(400).json({
        error: "Missing subject",
      });
    }

    const { data, error } = await supabase
      .from("curriculum_items")
      .select("topic")
      .eq("subject", subject)
      .eq("is_active", true);

    if (error) {
      return res.status(500).json({
        error: "Failed to fetch curriculum topics",
        details: error.message,
      });
    }

    const topics = [...new Set((data || []).map((row) => row.topic))]
      .filter(Boolean)
      .sort();

    return res.json({
      success: true,
      topics,
    });
  } catch (err) {
    console.error("Fetch curriculum topics error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});

// =========================
// FETCH CURRICULUM SUBTOPICS
// =========================
app.get("/curriculum/subtopics", async (req, res) => {
  try {
    const { subject, topic } = req.query;

    if (!subject || !topic) {
      return res.status(400).json({
        error: "Missing subject or topic",
      });
    }

    const { data, error } = await supabase
      .from("curriculum_items")
      .select("subtopic")
      .eq("subject", subject)
      .eq("topic", topic)
      .eq("is_active", true);

    if (error) {
      return res.status(500).json({
        error: "Failed to fetch curriculum subtopics",
        details: error.message,
      });
    }

    const subtopics = [...new Set((data || []).map((row) => row.subtopic))]
      .filter(Boolean)
      .sort();

    return res.json({
      success: true,
      subtopics,
    });
  } catch (err) {
    console.error("Fetch curriculum subtopics error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});

// =========================
// FETCH DRAFT QUIZ FOR TEACHER
// =========================
app.get("/teacher/quiz/:quizId", async (req, res) => {
  try {
    const { quizId } = req.params;

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("*")
      .eq("id", quizId)
      .maybeSingle();

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quiz",
        details: quizError.message,
      });
    }

    if (!quiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }

    const { data: questions, error: questionsError } = await supabase
      .from("smart_quiz_questions")
      .select("*")
      .eq("quiz_id", quizId)
      .order("order_index", { ascending: true });

    if (questionsError) {
      return res.status(500).json({
        error: "Failed to fetch questions",
        details: questionsError.message,
      });
    }

    const questionIds = (questions || []).map((q) => q.id);

    let options = [];
    if (questionIds.length > 0) {
      const { data: optionsData, error: optionsError } = await supabase
        .from("smart_quiz_options")
        .select("*")
        .in("question_id", questionIds)
        .order("order_index", { ascending: true });

      if (optionsError) {
        return res.status(500).json({
          error: "Failed to fetch options",
          details: optionsError.message,
        });
      }

      options = optionsData || [];
    }

    const optionsByQuestion = {};
    for (const option of options) {
      if (!optionsByQuestion[option.question_id]) {
        optionsByQuestion[option.question_id] = [];
      }
      optionsByQuestion[option.question_id].push(option);
    }

    const formattedQuestions = (questions || []).map((q) => ({
      ...q,
      options: optionsByQuestion[q.id] || [],
    }));

    return res.json({
      success: true,
      quiz,
      questions: formattedQuestions,
    });
  } catch (error) {
    console.error("Fetch draft quiz error:", error);
    return res.status(500).json({
      error: "Internal server error",
      details: error.message,
    });
  }
});

// =========================
// GET ALL QUIZZES FOR TEACHER
// =========================
app.get("/teacher/quizzes/:teacherId", async (req, res) => {
  try {
    const { teacherId } = req.params;

    const { data, error } = await supabase
      .from("smart_quizzes")
      .select("*")
      .eq("teacher_id", teacherId)
      .order("created_at", { ascending: false });

    if (error) {
      return res.status(500).json({
        error: "Failed to fetch quizzes",
        details: error.message,
      });
    }

    return res.json({
      success: true,
      quizzes: data || [],
    });
  } catch (err) {
    console.error("Fetch teacher quizzes error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});

// =========================
// DELETE QUIZ FOR TEACHER
// =========================
app.delete("/teacher/quiz/:quizId", async (req, res) => {
  try {
    const { quizId } = req.params;

    // 1. Check quiz exists and is still a draft
    const { data: existingQuiz, error: fetchQuizError } = await supabase
      .from("smart_quizzes")
      .select("id, status")
      .eq("id", quizId)
      .maybeSingle();

    if (fetchQuizError) {
      return res.status(500).json({
        error: "Failed to fetch quiz",
        details: fetchQuizError.message,
      });
    }

    if (!existingQuiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }

    if (existingQuiz.status !== "draft") {
      return res.status(400).json({
        error: "Only draft quizzes can be deleted",
      });
    }

    // 2. Fetch attempts linked to this quiz
    const { data: attempts, error: attemptsFetchError } = await supabase
      .from("smart_quiz_attempts")
      .select("id")
      .eq("quiz_id", quizId);

    if (attemptsFetchError) {
      return res.status(500).json({
        error: "Failed to fetch quiz attempts",
        details: attemptsFetchError.message,
      });
    }

    const attemptIds = (attempts || []).map((a) => a.id);

    // 3. Delete attempt answers first
    if (attemptIds.length > 0) {
      const { error: attemptAnswersDeleteError } = await supabase
        .from("smart_quiz_attempt_answers")
        .delete()
        .in("attempt_id", attemptIds);

      if (attemptAnswersDeleteError) {
        return res.status(500).json({
          error: "Failed to delete attempt answers",
          details: attemptAnswersDeleteError.message,
        });
      }
    }

    // 4. Delete attempts
    const { error: attemptsDeleteError } = await supabase
      .from("smart_quiz_attempts")
      .delete()
      .eq("quiz_id", quizId);

    if (attemptsDeleteError) {
      return res.status(500).json({
        error: "Failed to delete quiz attempts",
        details: attemptsDeleteError.message,
      });
    }

    // 5. Fetch questions linked to this quiz
    const { data: questions, error: questionsFetchError } = await supabase
      .from("smart_quiz_questions")
      .select("id")
      .eq("quiz_id", quizId);

    if (questionsFetchError) {
      return res.status(500).json({
        error: "Failed to fetch quiz questions",
        details: questionsFetchError.message,
      });
    }

    const questionIds = (questions || []).map((q) => q.id);

    // 6. Delete options first
    if (questionIds.length > 0) {
      const { error: optionsDeleteError } = await supabase
        .from("smart_quiz_options")
        .delete()
        .in("question_id", questionIds);

      if (optionsDeleteError) {
        return res.status(500).json({
          error: "Failed to delete quiz options",
          details: optionsDeleteError.message,
        });
      }
    }

    // 7. Delete questions
    const { error: questionsDeleteError } = await supabase
      .from("smart_quiz_questions")
      .delete()
      .eq("quiz_id", quizId);

    if (questionsDeleteError) {
      return res.status(500).json({
        error: "Failed to delete quiz questions",
        details: questionsDeleteError.message,
      });
    }

    // 8. Delete selected subtopics
    const { error: subtopicsDeleteError } = await supabase
      .from("smart_quiz_subtopics")
      .delete()
      .eq("quiz_id", quizId);

    if (subtopicsDeleteError) {
      return res.status(500).json({
        error: "Failed to delete quiz subtopics",
        details: subtopicsDeleteError.message,
      });
    }

    // 9. Delete assignments if any
    const { error: assignmentsDeleteError } = await supabase
      .from("smart_quiz_assignments")
      .delete()
      .eq("quiz_id", quizId);

    if (assignmentsDeleteError) {
      return res.status(500).json({
        error: "Failed to delete quiz assignments",
        details: assignmentsDeleteError.message,
      });
    }

    // 10. Finally delete the quiz itself
    const { error: quizDeleteError } = await supabase
      .from("smart_quizzes")
      .delete()
      .eq("id", quizId);

    if (quizDeleteError) {
      return res.status(500).json({
        error: "Failed to delete quiz",
        details: quizDeleteError.message,
      });
    }

    return res.json({
      success: true,
      message: "Quiz deleted successfully",
    });
  } catch (err) {
    console.error("Delete quiz error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});


// =========================
// UPDATE DRAFT QUIZ
// =========================
app.put("/teacher/quiz/:quizId", async (req, res) => {
  try {
    const { quizId } = req.params;
    // check quiz status first
    const { data: existingQuiz, error: fetchError } = await supabase
      .from("smart_quizzes")
      .select("status")
      .eq("id", quizId)
      .maybeSingle();

    if (fetchError || !existingQuiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }
    // 🔒 BLOCK if not draft
    if (existingQuiz.status !== "draft") {
      return res.status(400).json({
        error: "Only draft quizzes can be edited",
      });
    }
    const { title, questions } = req.body || {};
    if (!title && !Array.isArray(questions)) {
      return res.status(400).json({
        error: "Please provide a title and/or questions array in JSON body."
      });
    }

    // update quiz title
    if (title) {
      await supabase
        .from("smart_quizzes")
        .update({ title })
        .eq("id", quizId);
    }

    for (const question of questions) {
      const { id, question_text, correct_answer_text, explanation, options } = question;

      // update question
      await supabase
        .from("smart_quiz_questions")
        .update({
          question_text,
          correct_answer_text,
          explanation,
        })
        .eq("id", id);

      // update options if exist
      if (Array.isArray(options)) {
        for (const opt of options) {
          await supabase
            .from("smart_quiz_options")
            .update({
              option_text: opt.option_text,
              is_correct: opt.is_correct,
            })
            .eq("id", opt.id);
        }
      }
    }

    return res.json({
      success: true,
      message: "Draft quiz updated successfully",
    });
  } catch (error) {
    console.error("Update draft quiz error:", error);
    return res.status(500).json({
      error: "Internal server error",
      details: error.message,
    });
  }
});

// =========================
// PUBLISH QUIZ
// =========================
app.post("/teacher/quiz/:quizId/publish", async (req, res) => {
  try {
    const { quizId } = req.params;

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("*")
      .eq("id", quizId)
      .maybeSingle();

    if (quizError || !quiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }

    // update status
    const { error: updateError } = await supabase
      .from("smart_quizzes")
      .update({ status: "published" })
      .eq("id", quizId);

    if (updateError) {
      return res.status(500).json({
        error: "Failed to publish quiz",
        details: updateError.message,
      });
    }

    // assign to pupils
    const { data: pupils, error: pupilsError } = await supabase
      .from("pupils")
      .select("id, class_id")
      .eq("class_id", quiz.class_id);

    if (pupilsError) {
      return res.status(500).json({
        error: "Failed to fetch pupils",
        details: pupilsError.message,
      });
    }

    if (pupils && pupils.length > 0) {
      const assignments = pupils.map((pupil) => ({
        quiz_id: quizId,
        class_id: quiz.class_id,
        pupil_id: pupil.id,
      }));

      const { error: assignmentError } = await supabase
        .from("smart_quiz_assignments")
        .insert(assignments);

      if (assignmentError) {
        return res.status(500).json({
          error: "Failed to assign quiz",
          details: assignmentError.message,
        });
      }
    }

    return res.json({
      success: true,
      message: "Quiz published successfully",
    });
  } catch (error) {
    console.error("Publish quiz error:", error);
    return res.status(500).json({
      error: "Internal server error",
      details: error.message,
    });
  }
});

// =========================
// FETCH AVAILABLE QUIZZES FOR A PUPIL
// =========================
app.get("/pupil/:pupilId/quizzes", async (req, res) => {
  try {
    const { pupilId } = req.params;

    if (!pupilId) {
      return res.status(400).json({
        error: "Missing pupilId",
      });
    }

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
          difficulty,
          question_type,
          number_of_questions,
          time_limit_minutes,
          available_from,
          deadline_at,
          leaderboard_size,
          leaderboard_enabled,
          instant_result_enabled,
          reveal_answers_after_deadline,
          status,
          created_at
        )
      `)
      .eq("pupil_id", pupilId);

    if (assignmentsError) {
      return res.status(500).json({
        error: "Failed to fetch assigned quizzes",
        details: assignmentsError.message,
      });
    }

    const now = new Date();

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select(`
        id,
        quiz_id,
        status,
        started_at,
        submitted_at,
        score_percent,
        correct_answers,
        wrong_answers,
        unanswered_questions,
        duration_seconds
      `)
      .eq("pupil_id", pupilId);

    if (attemptsError) {
      return res.status(500).json({
        error: "Failed to fetch pupil attempts",
        details: attemptsError.message,
      });
    }

    const attemptsMap = new Map();
    for (const attempt of attempts || []) {
      attemptsMap.set(attempt.quiz_id, attempt);
    }

    const quizzes = (assignments || [])
      .map((assignment) => {
        const quiz = assignment.smart_quizzes;
        if (!quiz) return null;

        const attempt = attemptsMap.get(quiz.id) || null;
        const availableFrom = new Date(quiz.available_from);
        const deadlineAt = new Date(quiz.deadline_at);

        let availability_status = "upcoming";
        if (quiz.status !== "published") {
          availability_status = "inactive";
        } else if (now < availableFrom) {
          availability_status = "upcoming";
        } else if (now > deadlineAt) {
          availability_status = "closed";
        } else {
          availability_status = "open";
        }

        let participation_status = "not_started";
        if (attempt) {
          participation_status = attempt.status;
        } else if (now > deadlineAt) {
          participation_status = "not_participated";
        }

        return {
          quiz_id: quiz.id,
          class_id: assignment.class_id,
          title: quiz.title,
          subject: quiz.subject,
          topic: quiz.topic,
          subtopic: quiz.subtopic,
          difficulty: quiz.difficulty,
          question_type: quiz.question_type,
          number_of_questions: quiz.number_of_questions,
          time_limit_minutes: quiz.time_limit_minutes,
          available_from: quiz.available_from,
          deadline_at: quiz.deadline_at,
          leaderboard_size: quiz.leaderboard_size,
          leaderboard_enabled: quiz.leaderboard_enabled,
          instant_result_enabled: quiz.instant_result_enabled,
          reveal_answers_after_deadline: quiz.reveal_answers_after_deadline,
          quiz_status: quiz.status,
          availability_status,
          participation_status,
          attempt: attempt
            ? {
                attempt_id: attempt.id,
                status: attempt.status,
                started_at: attempt.started_at,
                submitted_at: attempt.submitted_at,
                score_percent: attempt.score_percent,
                correct_answers: attempt.correct_answers,
                wrong_answers: attempt.wrong_answers,
                unanswered_questions: attempt.unanswered_questions,
                duration_seconds: attempt.duration_seconds,
              }
            : null,
        };
      })
      .filter(Boolean);

    return res.json({
      success: true,
      pupil_id: pupilId,
      quizzes,
    });
  } catch (error) {
    console.error("Fetch pupil quizzes error:", error);
    return res.status(500).json({
      error: "Internal server error",
      details: error.message,
    });
  }
});


// =========================
// START QUIZ FOR PUPIL
// =========================
app.get("/pupil/:pupilId/quiz/:quizId/start", async (req, res) => {
  try {
    const { pupilId, quizId } = req.params;

    const { data: assignment, error: assignmentError } = await supabase
      .from("smart_quiz_assignments")
      .select("id, class_id")
      .eq("quiz_id", quizId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (assignmentError) {
      return res.status(500).json({
        error: "Failed to verify quiz assignment",
        details: assignmentError.message,
      });
    }

    if (!assignment) {
      return res.status(403).json({
        error: "Quiz is not assigned to this pupil",
      });
    }

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("*")
      .eq("id", quizId)
      .maybeSingle();

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quiz",
        details: quizError.message,
      });
    }

    if (!quiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }

    if (quiz.status !== "published") {
      return res.status(400).json({
        error: "Quiz is not available",
      });
    }

    const now = new Date();
    const availableFrom = new Date(quiz.available_from);
    const deadlineAt = new Date(quiz.deadline_at);

    if (now < availableFrom) {
      return res.status(400).json({
        error: "Quiz is not yet available",
      });
    }

    if (now > deadlineAt) {
      return res.status(400).json({
        error: "Quiz deadline is over",
      });
    }

    const { data: existingAttempt, error: existingAttemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("id, status")
      .eq("quiz_id", quizId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (existingAttemptError) {
      return res.status(500).json({
        error: "Failed to check existing attempt",
        details: existingAttemptError.message,
      });
    }

    if (existingAttempt && existingAttempt.status === "submitted") {
      return res.status(400).json({
        error: "Quiz already submitted",
      });
    }

    let attemptId = existingAttempt?.id || null;

    if (!attemptId) {
      const { data: newAttempt, error: attemptInsertError } = await supabase
        .from("smart_quiz_attempts")
        .insert({
          quiz_id: quizId,
          pupil_id: pupilId,
          class_id: assignment.class_id,
          status: "started",
          started_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (attemptInsertError) {
        return res.status(500).json({
          error: "Failed to create attempt",
          details: attemptInsertError.message,
        });
      }

      attemptId = newAttempt.id;
    }

    const { data: questions, error: questionsError } = await supabase
      .from("smart_quiz_questions")
      .select("*")
      .eq("quiz_id", quizId)
      .order("order_index", { ascending: true });

    if (questionsError) {
      return res.status(500).json({
        error: "Failed to fetch questions",
        details: questionsError.message,
      });
    }

    const questionIds = (questions || []).map((q) => q.id);

    let options = [];
    if (questionIds.length > 0) {
      const { data: optionsData, error: optionsError } = await supabase
        .from("smart_quiz_options")
        .select("*")
        .in("question_id", questionIds)
        .order("order_index", { ascending: true });

      if (optionsError) {
        return res.status(500).json({
          error: "Failed to fetch options",
          details: optionsError.message,
        });
      }

      options = optionsData || [];
    }

    const optionsMap = {};
    for (const option of options) {
      if (!optionsMap[option.question_id]) {
        optionsMap[option.question_id] = [];
      }
      optionsMap[option.question_id].push(option);
    }

    const formattedQuestions = (questions || []).map((q) => ({
      id: q.id,
      question_text: q.question_text,
      question_type: q.question_type,
      order_index: q.order_index,
      marks: q.marks,
      options: optionsMap[q.id] || [],
    }));

    return res.json({
      success: true,
      quiz: {
        id: quiz.id,
        title: quiz.title,
        subject: quiz.subject,
        topic: quiz.topic,
        number_of_questions: quiz.number_of_questions,
        time_limit_minutes: quiz.time_limit_minutes,
        available_from: quiz.available_from,
        deadline_at: quiz.deadline_at,
      },
      attempt_id: attemptId,
      questions: formattedQuestions,
    });
  } catch (err) {
    console.error("Start quiz error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// SUBMIT QUIZ FOR PUPIL
// =========================
app.post("/pupil/:pupilId/quiz/:quizId/submit", async (req, res) => {
  try {
    const { pupilId, quizId } = req.params;
    const { answers } = req.body;

    if (!Array.isArray(answers) || answers.length === 0) {
      return res.status(400).json({
        error: "Answers are required",
      });
    }

    const { data: attempt, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("*")
      .eq("quiz_id", quizId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (attemptError) {
      return res.status(500).json({
        error: "Failed to fetch attempt",
        details: attemptError.message,
      });
    }

    if (!attempt) {
      return res.status(404).json({
        error: "Attempt not found",
      });
    }

    if (attempt.status === "submitted") {
      return res.status(400).json({
        error: "Quiz already submitted",
      });
    }

    const { data: questions, error: questionsError } = await supabase
      .from("smart_quiz_questions")
      .select("*")
      .eq("quiz_id", quizId)
      .order("order_index", { ascending: true });

    if (questionsError) {
      return res.status(500).json({
        error: "Failed to fetch quiz questions",
        details: questionsError.message,
      });
    }

    const questionIds = (questions || []).map((q) => q.id);

    let options = [];
    if (questionIds.length > 0) {
      const { data: optionsData, error: optionsError } = await supabase
        .from("smart_quiz_options")
        .select("*")
        .in("question_id", questionIds);

      if (optionsError) {
        return res.status(500).json({
          error: "Failed to fetch options",
          details: optionsError.message,
        });
      }

      options = optionsData || [];
    }

    const optionsMap = {};
    for (const option of options) {
      if (!optionsMap[option.question_id]) {
        optionsMap[option.question_id] = [];
      }
      optionsMap[option.question_id].push(option);
    }

    // remove previous saved answers for this in-progress attempt if any
    const { error: deleteExistingAnswersError } = await supabase
      .from("smart_quiz_attempt_answers")
      .delete()
      .eq("attempt_id", attempt.id);

    if (deleteExistingAnswersError) {
      return res.status(500).json({
        error: "Failed to reset previous answers",
        details: deleteExistingAnswersError.message,
      });
    }

    let totalScore = 0;
    let totalPossible = 0;
    const answerRows = [];
    const review = [];

    for (const question of questions || []) {
      totalPossible += Number(question.marks || 1);

      const submitted = answers.find((a) => a.question_id === question.id);
      const pupilAnswer = submitted?.answer_text ?? "";

      let isCorrect = false;

      if (question.question_type === "fill_blank") {
        isCorrect =
          String(pupilAnswer).trim().toLowerCase() ===
          String(question.correct_answer_text || "").trim().toLowerCase();
      } else {
        const correctOption = (optionsMap[question.id] || []).find(
          (o) => o.is_correct === true
        );
        const correctText =
          correctOption?.option_text || question.correct_answer_text || "";
        isCorrect =
          String(pupilAnswer).trim().toLowerCase() ===
          String(correctText).trim().toLowerCase();
      }

      const awardedMarks = isCorrect ? Number(question.marks || 1) : 0;
      totalScore += awardedMarks;

      answerRows.push({
        attempt_id: attempt.id,
        question_id: question.id,
        selected_option_id: null,
        answer_text: pupilAnswer,
        is_correct: isCorrect,
        marks_awarded: awardedMarks,
        answered_at: new Date().toISOString(),
      });
      let reviewCorrectAnswerText = question.correct_answer_text || "";

      if (question.question_type === "mcq" || question.question_type === "true_false") {
        const correctOption = (optionsMap[question.id] || []).find(
          (o) => o.is_correct === true
        );
        reviewCorrectAnswerText = correctOption?.option_text || reviewCorrectAnswerText;
      }  
      review.push({
        question_id: question.id,
        question_text: question.question_text,
        question_type: question.question_type,
        pupil_answer_text: pupilAnswer,
        correct_answer_text: reviewCorrectAnswerText,
        explanation: question.explanation,
        marks: question.marks,
        marks_awarded: awardedMarks,
        is_correct: isCorrect,
        options: optionsMap[question.id] || [],
      });
    }

    const { error: insertAnswersError } = await supabase
      .from("smart_quiz_attempt_answers")
      .insert(answerRows);

    if (insertAnswersError) {
      return res.status(500).json({
        error: "Failed to save attempt answers",
        details: insertAnswersError.message,
      });
    }

    const duration = calculateDurationSeconds(
      attempt.started_at,
      new Date().toISOString()
    );

    const scorePercent =
      totalPossible > 0 ? Math.round((totalScore / totalPossible) * 100) : 0;

    const correctAnswers = answerRows.filter((a) => a.is_correct).length;
    const wrongAnswers = answerRows.filter(
      (a) => a.answer_text && !a.is_correct
    ).length;
    const unansweredQuestions = answerRows.filter(
      (a) => !a.answer_text || a.answer_text.trim() === ""
    ).length;

    const { error: updateAttemptError } = await supabase
      .from("smart_quiz_attempts")
      .update({
        status: "submitted",
        submitted_at: new Date().toISOString(),
        score_percent: scorePercent,
        correct_answers: correctAnswers,
        wrong_answers: wrongAnswers,
        unanswered_questions: unansweredQuestions,
        duration_seconds: duration,
      })
      .eq("id", attempt.id);

    if (updateAttemptError) {
      return res.status(500).json({
        error: "Failed to finalize attempt",
        details: updateAttemptError.message,
      });
    }

    return res.json({
      success: true,
      message: "Quiz submitted successfully",
      attempt_id: attempt.id,
      score: totalScore,
      total_possible: totalPossible,
      review,
    });
    
  } catch (err) {
    console.error("Submit quiz error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// FETCH ALL RESULTS FOR A PUPIL
// =========================
app.get("/pupil/:pupilId/results", async (req, res) => {
  try {
    const { pupilId } = req.params;

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select(`
        id,
        quiz_id,
        pupil_id,
        status,
        started_at,
        submitted_at,
        score_percent,
        correct_answers,
        wrong_answers,
        unanswered_questions,
        duration_seconds,
        smart_quizzes (
          id,
          title,
          subject,
          topic,
          subtopic,
          number_of_questions
        )
      `)
      .eq("pupil_id", pupilId)
      .eq("status", "submitted")
      .order("submitted_at", { ascending: false });

    if (attemptsError) {
      return res.status(500).json({
        error: "Failed to fetch pupil results",
        details: attemptsError.message,
      });
    }

    const results = (attempts || []).map((attempt) => ({
      attempt_id: attempt.id,
      quiz_id: attempt.quiz_id,
      title: attempt.smart_quizzes?.title || "",
      subject: attempt.smart_quizzes?.subject || "",
      topic: attempt.smart_quizzes?.topic || "",
      subtopic: attempt.smart_quizzes?.subtopic || "",
      number_of_questions: attempt.smart_quizzes?.number_of_questions || 0,
      submitted_at: attempt.submitted_at,
      score_percent: attempt.score_percent ?? 0,
      correct_answers: attempt.correct_answers ?? 0,
      wrong_answers: attempt.wrong_answers ?? 0,
      unanswered_questions: attempt.unanswered_questions ?? 0,
      duration_seconds: attempt.duration_seconds ?? 0,
    }));

    return res.json({
      success: true,
      results,
    });
  } catch (err) {
    console.error("Fetch pupil results error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});

// =========================
// FETCH SINGLE RESULT REVIEW
// =========================
app.get("/pupil/:pupilId/result/:attemptId", async (req, res) => {
  try {
    const { pupilId, attemptId } = req.params;

    const { data: attempt, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select(`
        *,
        smart_quizzes (
          id,
          title,
          subject,
          topic,
          subtopic,
          number_of_questions
        )
      `)
      .eq("id", attemptId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (attemptError) {
      return res.status(500).json({
        error: "Failed to fetch attempt",
        details: attemptError.message,
      });
    }

    if (!attempt) {
      return res.status(404).json({
        error: "Result not found",
      });
    }

    const { data: answerRows, error: answersError } = await supabase
      .from("smart_quiz_attempt_answers")
      .select(`
        attempt_id,
        question_id,
        answer_text,
        is_correct,
        marks_awarded,
        smart_quiz_questions (
          id,
          question_text,
          question_type,
          correct_answer_text,
          explanation,
          marks
        )
      `)
      .eq("attempt_id", attemptId);

    if (answersError) {
      return res.status(500).json({
        error: "Failed to fetch result answers",
        details: answersError.message,
      });
    }

    const questionIds = (answerRows || [])
      .map((row) => row.smart_quiz_questions?.id)
      .filter(Boolean);

    let options = [];
    if (questionIds.length > 0) {
      const { data: optionsData, error: optionsError } = await supabase
        .from("smart_quiz_options")
        .select("*")
        .in("question_id", questionIds)
        .order("order_index", { ascending: true });

      if (optionsError) {
        return res.status(500).json({
          error: "Failed to fetch question options",
          details: optionsError.message,
        });
      }

      options = optionsData || [];
    }

    const optionsMap = {};
    for (const option of options) {
      if (!optionsMap[option.question_id]) {
        optionsMap[option.question_id] = [];
      }
      optionsMap[option.question_id].push(option);
    }

    const review = (answerRows || []).map((row) => {
      const q = row.smart_quiz_questions;

      let reviewCorrectAnswerText = q?.correct_answer_text || "";

      if (q?.question_type === "mcq" || q?.question_type === "true_false") {
        const correctOption = (optionsMap[q.id] || []).find(
          (o) => o.is_correct === true
        );
        reviewCorrectAnswerText =
          correctOption?.option_text || reviewCorrectAnswerText;
      }

      return {
        question_id: q?.id,
        question_text: q?.question_text || "",
        question_type: q?.question_type || "",
        pupil_answer_text: row.answer_text || "",
        correct_answer_text: reviewCorrectAnswerText,
        explanation: q?.explanation || "",
        marks: q?.marks || 1,
        marks_awarded: row.marks_awarded || 0,
        is_correct: row.is_correct === true,
        options: optionsMap[q?.id] || [],
      };
    });

    const totalPossible = review.reduce(
      (sum, item) => sum + Number(item.marks || 0),
      0
    );

    const score = review.reduce(
      (sum, item) => sum + Number(item.marks_awarded || 0),
      0
    );

    return res.json({
      success: true,
      quizTitle: attempt.smart_quizzes?.title || "",
      score,
      total_possible: totalPossible,
      review,
    });
  } catch (err) {
    console.error("Fetch single result review error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// TEACHER QUIZ RESULTS DETAILS
// =========================
app.get("/teacher/:teacherId/results/quiz/:quizId", async (req, res) => {
  try {
    const { teacherId, quizId } = req.params;

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, title, subject, topic, subtopic, class_id, teacher_id, leaderboard_published")
      .eq("id", quizId)
      .eq("teacher_id", teacherId)
      .maybeSingle();

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quiz",
        details: quizError.message,
      });
    }

    if (!quiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }

    const { data: pupils, error: pupilsError } = await supabase
      .from("pupils")
      .select("id, full_name, username, class_id")
      .eq("class_id", quiz.class_id);

    if (pupilsError) {
      return res.status(500).json({
        error: "Failed to fetch pupils",
        details: pupilsError.message,
      });
    }

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select("*")
      .eq("quiz_id", quizId);

    if (attemptsError) {
      return res.status(500).json({
        error: "Failed to fetch attempts",
        details: attemptsError.message,
      });
    }

    const attemptsMap = {};
    for (const attempt of attempts || []) {
      attemptsMap[attempt.pupil_id] = attempt;
    }

    const pupilResults = (pupils || []).map((pupil) => {
      const attempt = attemptsMap[pupil.id];

      return {
        pupil_id: pupil.id,
        full_name: pupil.full_name,
        username: pupil.username,
        status: attempt ? attempt.status : "not_started",
        attempt_id: attempt?.id || null,
        score_percent: attempt?.score_percent ?? null,
      };
    });

    const submittedCount = pupilResults.filter(p => p.status === "submitted").length;
    const startedCount = pupilResults.filter(p => p.status === "started").length;
    const notStartedCount = pupilResults.filter(p => p.status === "not_started").length;

    return res.json({
      success: true,
      quiz,
      summary: {
        submitted_count: submittedCount,
        started_count: startedCount,
        not_started_count: notStartedCount,
      },
      pupils: pupilResults,
    });

  } catch (err) {
    console.error("Teacher quiz results error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// PUBLISH LEADERBOARD FOR QUIZ
// =========================
app.post("/teacher/:teacherId/results/quiz/:quizId/publish-leaderboard", async (req, res) => {
  try {
    const { teacherId, quizId } = req.params;

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, teacher_id, status, leaderboard_published")
      .eq("id", quizId)
      .eq("teacher_id", teacherId)
      .maybeSingle();

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quiz",
        details: quizError.message,
      });
    }

    if (!quiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }

    if (quiz.status !== "published") {
      return res.status(400).json({
        error: "Leaderboard can only be published for a published quiz",
      });
    }

    if (quiz.leaderboard_published === true) {
      return res.json({
        success: true,
        message: "Leaderboard already published",
      });
    }

    const { error: updateError } = await supabase
      .from("smart_quizzes")
      .update({
        leaderboard_published: true,
      })
      .eq("id", quizId);

    if (updateError) {
      return res.status(500).json({
        error: "Failed to publish leaderboard",
        details: updateError.message,
      });
    }

    return res.json({
      success: true,
      message: "Leaderboard published successfully",
    });
  } catch (err) {
    console.error("Publish leaderboard error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// TEACHER RESULTS OVERVIEW
// =========================
app.get("/teacher/:teacherId/results/overview", async (req, res) => {
  try {
    const { teacherId } = req.params;
    const { class_id } = req.query;

    const { data: classes, error: classesError } = await supabase
      .from("classes")
      .select("id, class_name")
      .eq("teacher_id", teacherId)
      .order("class_name", { ascending: true });

    if (classesError) {
      return res.status(500).json({
        error: "Failed to fetch teacher classes",
        details: classesError.message,
      });
    }

    let classIds = (classes || []).map((c) => c.id);

    if (class_id) {
      classIds = classIds.filter((id) => id === class_id);
    }

    if (classIds.length === 0) {
      return res.json({
        success: true,
        classes: classes || [],
        quiz_summaries: [],
      });
    }

    const { data: quizzes, error: quizzesError } = await supabase
      .from("smart_quizzes")
      .select("id, title, subject, topic, subtopic, class_id, status, created_at")
      .eq("teacher_id", teacherId)
      .eq("status", "published")
      .in("class_id", classIds)
      .order("created_at", { ascending: false });

    if (quizzesError) {
      return res.status(500).json({
        error: "Failed to fetch teacher quizzes",
        details: quizzesError.message,
      });
    }

    const quizIds = (quizzes || []).map((q) => q.id);

    const { data: pupils, error: pupilsError } = await supabase
      .from("pupils")
      .select("id, class_id")
      .in("class_id", classIds);

    if (pupilsError) {
      return res.status(500).json({
        error: "Failed to fetch pupils",
        details: pupilsError.message,
      });
    }

    let attempts = [];
    if (quizIds.length > 0) {
      const { data: attemptsData, error: attemptsError } = await supabase
        .from("smart_quiz_attempts")
        .select("id, quiz_id, pupil_id, status, score_percent")
        .in("quiz_id", quizIds);

      if (attemptsError) {
        return res.status(500).json({
          error: "Failed to fetch attempts",
          details: attemptsError.message,
        });
      }

      attempts = attemptsData || [];
    }

    const classMap = {};
    for (const c of classes || []) {
      classMap[c.id] = c.class_name;
    }

    const pupilsByClass = {};
    for (const pupil of pupils || []) {
      if (!pupilsByClass[pupil.class_id]) {
        pupilsByClass[pupil.class_id] = [];
      }
      pupilsByClass[pupil.class_id].push(pupil);
    }

    const attemptsByQuiz = {};
    for (const attempt of attempts) {
      if (!attemptsByQuiz[attempt.quiz_id]) {
        attemptsByQuiz[attempt.quiz_id] = [];
      }
      attemptsByQuiz[attempt.quiz_id].push(attempt);
    }

    const quizSummaries = (quizzes || []).map((quiz) => {
      const classPupils = pupilsByClass[quiz.class_id] || [];
      const quizAttempts = attemptsByQuiz[quiz.id] || [];
      const submittedAttempts = quizAttempts.filter((a) => a.status === "submitted");

      const avgScore =
        submittedAttempts.length > 0
          ? Math.round(
              submittedAttempts.reduce(
                (sum, a) => sum + Number(a.score_percent || 0),
                0
              ) / submittedAttempts.length
            )
          : 0;

      const highestScore =
        submittedAttempts.length > 0
          ? Math.max(...submittedAttempts.map((a) => Number(a.score_percent || 0)))
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

    return res.json({
      success: true,
      classes: classes || [],
      quiz_summaries: quizSummaries,
    });
  } catch (err) {
    console.error("Teacher results overview error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// TEACHER VIEW SINGLE ATTEMPT REVIEW
// =========================
app.get("/teacher/:teacherId/result/:attemptId", async (req, res) => {
  try {
    const { teacherId, attemptId } = req.params;

    const { data: attempt, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("*")
      .eq("id", attemptId)
      .maybeSingle();

    if (attemptError) {
      return res.status(500).json({
        error: "Failed to fetch attempt",
        details: attemptError.message,
      });
    }

    if (!attempt) {
      return res.status(404).json({
        error: "Attempt not found",
      });
    }

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, title, teacher_id")
      .eq("id", attempt.quiz_id)
      .eq("teacher_id", teacherId)
      .maybeSingle();

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quiz",
        details: quizError.message,
      });
    }

    if (!quiz) {
      return res.status(403).json({
        error: "You do not have access to this result",
      });
    }

    const { data: pupil, error: pupilError } = await supabase
      .from("pupils")
      .select("id, full_name, username")
      .eq("id", attempt.pupil_id)
      .maybeSingle();

    if (pupilError) {
      return res.status(500).json({
        error: "Failed to fetch pupil",
        details: pupilError.message,
      });
    }

    const { data: answerRows, error: answersError } = await supabase
      .from("smart_quiz_attempt_answers")
      .select(`
        attempt_id,
        question_id,
        answer_text,
        is_correct,
        marks_awarded,
        smart_quiz_questions (
          id,
          question_text,
          question_type,
          correct_answer_text,
          explanation,
          marks
        )
      `)
      .eq("attempt_id", attemptId);

    if (answersError) {
      return res.status(500).json({
        error: "Failed to fetch attempt answers",
        details: answersError.message,
      });
    }

    const questionIds = (answerRows || [])
      .map((row) => row.smart_quiz_questions?.id)
      .filter(Boolean);

    let options = [];
    if (questionIds.length > 0) {
      const { data: optionsData, error: optionsError } = await supabase
        .from("smart_quiz_options")
        .select("*")
        .in("question_id", questionIds)
        .order("order_index", { ascending: true });

      if (optionsError) {
        return res.status(500).json({
          error: "Failed to fetch question options",
          details: optionsError.message,
        });
      }

      options = optionsData || [];
    }

    const optionsMap = {};
    for (const option of options) {
      if (!optionsMap[option.question_id]) {
        optionsMap[option.question_id] = [];
      }
      optionsMap[option.question_id].push(option);
    }

    const review = (answerRows || []).map((row) => {
      const q = row.smart_quiz_questions;

      let reviewCorrectAnswerText = q?.correct_answer_text || "";

      if (q?.question_type === "mcq" || q?.question_type === "true_false") {
        const correctOption = (optionsMap[q.id] || []).find(
          (o) => o.is_correct === true
        );
        reviewCorrectAnswerText =
          correctOption?.option_text || reviewCorrectAnswerText;
      }

      return {
        question_id: q?.id,
        question_text: q?.question_text || "",
        question_type: q?.question_type || "",
        pupil_answer_text: row.answer_text || "",
        correct_answer_text: reviewCorrectAnswerText,
        explanation: q?.explanation || "",
        marks: q?.marks || 1,
        marks_awarded: row.marks_awarded || 0,
        is_correct: row.is_correct === true,
        options: optionsMap[q?.id] || [],
      };
    });

    const totalPossible = review.reduce(
      (sum, item) => sum + Number(item.marks || 0),
      0
    );

    const score = review.reduce(
      (sum, item) => sum + Number(item.marks_awarded || 0),
      0
    );

    return res.json({
      success: true,
      quizTitle: quiz.title,
      pupilName: pupil?.full_name || "",
      pupilUsername: pupil?.username || "",
      score,
      total_possible: totalPossible,
      score_percent: attempt.score_percent ?? 0,
      review,
    });
  } catch (err) {
    console.error("Teacher single attempt review error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// FETCH PUBLISHED LEADERBOARDS FOR A PUPIL
// =========================
app.get("/pupil/:pupilId/leaderboards", async (req, res) => {
  try {
    const { pupilId } = req.params;

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
      return res.status(500).json({
        error: "Failed to fetch leaderboard assignments",
        details: assignmentsError.message,
      });
    }

    const quizzes = (assignments || [])
      .map((assignment) => assignment.smart_quizzes)
      .filter(
        (quiz) =>
          quiz &&
          quiz.status === "published" &&
          quiz.leaderboard_published === true
      );

    const quizIds = quizzes.map((q) => q.id);

    let attempts = [];
    if (quizIds.length > 0) {
      const { data: attemptsData, error: attemptsError } = await supabase
        .from("smart_quiz_attempts")
        .select("quiz_id, status, score_percent")
        .eq("pupil_id", pupilId)
        .in("quiz_id", quizIds);

      if (attemptsError) {
        return res.status(500).json({
          error: "Failed to fetch pupil leaderboard attempts",
          details: attemptsError.message,
        });
      }

      attempts = attemptsData || [];
    }

    const attemptsMap = {};
    for (const attempt of attempts) {
      attemptsMap[attempt.quiz_id] = attempt;
    }

    const leaderboards = quizzes.map((quiz) => {
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

    return res.json({
      success: true,
      leaderboards,
    });
  } catch (err) {
    console.error("Fetch pupil leaderboards error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});

// =========================
// FETCH SINGLE LEADERBOARD DETAILS FOR A PUPIL
// =========================
app.get("/pupil/:pupilId/leaderboard/:quizId", async (req, res) => {
  try {
    const { pupilId, quizId } = req.params;

    const { data: assignment, error: assignmentError } = await supabase
      .from("smart_quiz_assignments")
      .select("id, class_id")
      .eq("quiz_id", quizId)
      .eq("pupil_id", pupilId)
      .maybeSingle();

    if (assignmentError) {
      return res.status(500).json({
        error: "Failed to verify leaderboard assignment",
        details: assignmentError.message,
      });
    }

    if (!assignment) {
      return res.status(403).json({
        error: "This leaderboard is not assigned to this pupil",
      });
    }

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, title, subject, topic, subtopic, leaderboard_published, status")
      .eq("id", quizId)
      .maybeSingle();

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quiz",
        details: quizError.message,
      });
    }

    if (!quiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }

    if (quiz.status !== "published" || quiz.leaderboard_published !== true) {
      return res.status(403).json({
        error: "Leaderboard is not available",
      });
    }

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select("id, pupil_id, score_percent, duration_seconds, submitted_at, status")
      .eq("quiz_id", quizId)
      .eq("status", "submitted");

    if (attemptsError) {
      return res.status(500).json({
        error: "Failed to fetch leaderboard attempts",
        details: attemptsError.message,
      });
    }

    const submittedAttempts = attempts || [];
    const submittedPupilIds = submittedAttempts.map((a) => a.pupil_id);

    let pupils = [];
    if (submittedPupilIds.length > 0) {
      const { data: pupilsData, error: pupilsError } = await supabase
        .from("pupils")
        .select("id, full_name, username")
        .in("id", submittedPupilIds);

      if (pupilsError) {
        return res.status(500).json({
          error: "Failed to fetch leaderboard pupils",
          details: pupilsError.message,
        });
      }

      pupils = pupilsData || [];
    }

    const pupilMap = {};
    for (const pupil of pupils) {
      pupilMap[pupil.id] = pupil;
    }

    const ranked = submittedAttempts
      .map((attempt) => ({
        pupil_id: attempt.pupil_id,
        full_name: pupilMap[attempt.pupil_id]?.full_name || "Pupil",
        username: pupilMap[attempt.pupil_id]?.username || "",
        score_percent: Number(attempt.score_percent || 0),
        duration_seconds: Number(attempt.duration_seconds || 0),
        submitted_at: attempt.submitted_at,
      }))
      .sort((a, b) => {
        if (b.score_percent !== a.score_percent) {
          return b.score_percent - a.score_percent;
        }
        if (a.duration_seconds !== b.duration_seconds) {
          return a.duration_seconds - b.duration_seconds;
        }
        return new Date(a.submitted_at) - new Date(b.submitted_at);
      });

    const podium = ranked.slice(0, 3).map((item, index) => ({
      place: index + 1,
      ...item,
    }));

    const currentPupilEntry = ranked.find((item) => item.pupil_id === pupilId) || null;

    return res.json({
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
    });
  } catch (err) {
    console.error("Fetch single leaderboard error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// SUBTOPIC ANALYTICS (ONLY QUIZZED ONES)
// =========================
app.get("/analytics/subtopics/:teacherId", async (req, res) => {
  try {
    const { teacherId } = req.params;

    // Step 1: get teacher quizzes
    const { data: quizzes, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, subject, topic, subtopic")
      .eq("teacher_id", teacherId)
      .eq("status", "published");

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quizzes",
        details: quizError.message,
      });
    }

    if (!quizzes || quizzes.length === 0) {
      return res.json({ success: true, subtopics: [] });
    }

    const quizIds = quizzes.map(q => q.id);

    // Step 2: get attempts
    const { data: attempts, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("quiz_id, score_percent")
      .eq("status", "submitted")
      .in("quiz_id", quizIds);

    if (attemptError) {
      return res.status(500).json({
        error: "Failed to fetch attempts",
        details: attemptError.message,
      });
    }

    // Step 3: group by subtopic
    const subtopicMap = {};

    for (const quiz of quizzes) {
      const key = quiz.subtopic;

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
      for (const subtopicKey in subtopicMap) {
        if (subtopicMap[subtopicKey].quizzes.includes(attempt.quiz_id)) {
          subtopicMap[subtopicKey].totalScore += Number(attempt.score_percent || 0);
          subtopicMap[subtopicKey].totalAttempts += 1;
        }
      }
    }

    // Step 4: compute averages
    const result = Object.values(subtopicMap).map(item => ({
      subject: item.subject,
      topic: item.topic,
      subtopic: item.subtopic,
      quizzes_count: item.quizzes.length,
      attempts_count: item.totalAttempts,
      average_score:
        item.totalAttempts > 0
          ? Math.round(item.totalScore / item.totalAttempts)
          : 0,
    }));

    // Step 5: sort by weakest first (important!)
    result.sort((a, b) => a.average_score - b.average_score);

    return res.json({
      success: true,
      subtopics: result,
    });

  } catch (err) {
    console.error("Subtopic analytics error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// PUPIL ANALYTICS
// =========================
app.get("/analytics/pupil/:pupilId", async (req, res) => {
  try {
    const { pupilId } = req.params;

    // Step 1: get all attempts
    const { data: attempts, error: attemptError } = await supabase
      .from("smart_quiz_attempts")
      .select("quiz_id, score_percent")
      .eq("pupil_id", pupilId)
      .eq("status", "submitted");

    if (attemptError) {
      return res.status(500).json({
        error: "Failed to fetch attempts",
        details: attemptError.message,
      });
    }

    if (!attempts || attempts.length === 0) {
      return res.json({
        success: true,
        overall: {
          average_score: 0,
          attempts: 0,
        },
        subtopics: [],
      });
    }

    const quizIds = attempts.map(a => a.quiz_id);

    // Step 2: get quizzes info
    const { data: quizzes, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, subject, topic, subtopic")
      .in("id", quizIds);

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quizzes",
        details: quizError.message,
      });
    }

    // Step 3: overall stats
    let totalScore = 0;
    for (const a of attempts) {
      totalScore += Number(a.score_percent || 0);
    }

    const overallAverage = Math.round(totalScore / attempts.length);

    // Step 4: subtopic grouping
    const subtopicMap = {};

    for (const attempt of attempts) {
      const quiz = quizzes.find(q => q.id === attempt.quiz_id);
      if (!quiz) continue;

      const key = quiz.subtopic;

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

    const subtopics = Object.values(subtopicMap).map(item => ({
      subtopic: item.subtopic,
      subject: item.subject,
      topic: item.topic,
      average_score: Math.round(item.totalScore / item.count),
    }));

    return res.json({
      success: true,
      overall: {
        average_score: overallAverage,
        attempts: attempts.length,
      },
      subtopics: subtopics,
    });

  } catch (err) {
    console.error("Pupil analytics error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// QUIZ ANALYTICS OVERVIEW
// =========================
app.get("/analytics/quizzes/:teacherId", async (req, res) => {
  try {
    const { teacherId } = req.params;

    const { data: classes, error: classesError } = await supabase
      .from("classes")
      .select("id, class_name")
      .eq("teacher_id", teacherId);

    if (classesError) {
      return res.status(500).json({
        error: "Failed to fetch classes",
        details: classesError.message,
      });
    }

    const classMap = {};
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
      return res.status(500).json({
        error: "Failed to fetch quizzes",
        details: quizzesError.message,
      });
    }

    if (!quizzes || quizzes.length === 0) {
      return res.json({
        success: true,
        quizzes: [],
      });
    }

    const quizIds = quizzes.map((q) => q.id);
    const classIds = [...new Set(quizzes.map((q) => q.class_id))];

    const { data: pupils, error: pupilsError } = await supabase
      .from("pupils")
      .select("id, class_id")
      .in("class_id", classIds);

    if (pupilsError) {
      return res.status(500).json({
        error: "Failed to fetch pupils",
        details: pupilsError.message,
      });
    }

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select("quiz_id, pupil_id, status, score_percent")
      .in("quiz_id", quizIds);

    if (attemptsError) {
      return res.status(500).json({
        error: "Failed to fetch attempts",
        details: attemptsError.message,
      });
    }

    const pupilsByClass = {};
    for (const pupil of pupils || []) {
      if (!pupilsByClass[pupil.class_id]) {
        pupilsByClass[pupil.class_id] = [];
      }
      pupilsByClass[pupil.class_id].push(pupil);
    }

    const attemptsByQuiz = {};
    for (const attempt of attempts || []) {
      if (!attemptsByQuiz[attempt.quiz_id]) {
        attemptsByQuiz[attempt.quiz_id] = [];
      }
      attemptsByQuiz[attempt.quiz_id].push(attempt);
    }

    const result = quizzes
      .map((quiz) => {
        const classPupils = pupilsByClass[quiz.class_id] || [];
        const quizAttempts = attemptsByQuiz[quiz.id] || [];

        const submitted = quizAttempts.filter((a) => a.status === "submitted");
        const started = quizAttempts.filter(
          (a) => a.status === "started" || a.status === "in_progress"
        );

        const submittedScores = submitted.map((a) => Number(a.score_percent || 0));

        const averageScore =
          submittedScores.length > 0
            ? Math.round(
                submittedScores.reduce((sum, score) => sum + score, 0) /
                  submittedScores.length
              )
            : 0;

        const highestScore =
          submittedScores.length > 0 ? Math.max(...submittedScores) : 0;

        const lowestScore =
          submittedScores.length > 0 ? Math.min(...submittedScores) : 0;

        const notAttempted = Math.max(
          0,
          classPupils.length - submitted.length - started.length
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
      .filter((quiz) => quiz.submitted_count > 0);

    return res.json({
      success: true,
      quizzes: result,
    });
  } catch (err) {
    console.error("Quiz analytics overview error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// QUIZ ANALYTICS DETAILS
// =========================
app.get("/analytics/quiz/:quizId", async (req, res) => {
  try {
    const { quizId } = req.params;

    const { data: quiz, error: quizError } = await supabase
      .from("smart_quizzes")
      .select("id, title, subject, topic, subtopic, number_of_questions")
      .eq("id", quizId)
      .maybeSingle();

    if (quizError) {
      return res.status(500).json({
        error: "Failed to fetch quiz",
        details: quizError.message,
      });
    }

    if (!quiz) {
      return res.status(404).json({
        error: "Quiz not found",
      });
    }

    const { data: questions, error: questionsError } = await supabase
      .from("smart_quiz_questions")
      .select("id, question_text, order_index, marks")
      .eq("quiz_id", quizId)
      .order("order_index", { ascending: true });

    if (questionsError) {
      return res.status(500).json({
        error: "Failed to fetch questions",
        details: questionsError.message,
      });
    }

    const questionIds = (questions || []).map((q) => q.id);

    let answers = [];
    if (questionIds.length > 0) {
      const { data: answersData, error: answersError } = await supabase
        .from("smart_quiz_attempt_answers")
        .select("question_id, is_correct, answer_text")
        .in("question_id", questionIds);

      if (answersError) {
        return res.status(500).json({
          error: "Failed to fetch answers",
          details: answersError.message,
        });
      }

      answers = answersData || [];
    }

    const analytics = (questions || []).map((question) => {
      const qAnswers = answers.filter((a) => a.question_id === question.id);
      const correct = qAnswers.filter((a) => a.is_correct === true).length;
      const wrong = qAnswers.filter(
        (a) => a.answer_text && a.answer_text.trim() !== "" && a.is_correct !== true
      ).length;
      const skipped = qAnswers.filter(
        (a) => !a.answer_text || a.answer_text.trim() === ""
      ).length;

      const totalResponses = qAnswers.length;
      const correctRate =
        totalResponses > 0 ? Math.round((correct / totalResponses) * 100) : 0;

      return {
        question_id: question.id,
        question_text: question.question_text,
        order_index: question.order_index,
        total_responses: totalResponses,
        correct_count: correct,
        wrong_count: wrong,
        skipped_count: skipped,
        correct_rate: correctRate,
      };
    });

    const sortedByDifficulty = [...analytics].sort(
      (a, b) => a.correct_rate - b.correct_rate
    );

    const hardestQuestion =
      sortedByDifficulty.length > 0 ? sortedByDifficulty[0] : null;
    const easiestQuestion =
      sortedByDifficulty.length > 0
        ? sortedByDifficulty[sortedByDifficulty.length - 1]
        : null;

    return res.json({
      success: true,
      quiz,
      questions: analytics,
      highlights: {
        hardest_question: hardestQuestion,
        easiest_question: easiestQuestion,
      },
    });
  } catch (err) {
    console.error("Quiz analytics details error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// OVERALL ANALYTICS SUMMARY
// =========================
app.get("/analytics/overall/:teacherId", async (req, res) => {
  try {
    const { teacherId } = req.params;

    const { data: classes, error: classesError } = await supabase
      .from("classes")
      .select("id, class_name")
      .eq("teacher_id", teacherId);

    if (classesError) {
      return res.status(500).json({
        error: "Failed to fetch classes",
        details: classesError.message,
      });
    }

    const classIds = (classes || []).map((c) => c.id);

    const { data: quizzes, error: quizzesError } = await supabase
      .from("smart_quizzes")
      .select("id, subject, class_id, status")
      .eq("teacher_id", teacherId)
      .eq("status", "published");

    if (quizzesError) {
      return res.status(500).json({
        error: "Failed to fetch quizzes",
        details: quizzesError.message,
      });
    }

    if (!quizzes || quizzes.length === 0) {
      return res.json({
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
      });
    }

    const quizIds = quizzes.map((q) => q.id);

    let pupils = [];
    if (classIds.length > 0) {
      const { data: pupilsData, error: pupilsError } = await supabase
        .from("pupils")
        .select("id, class_id")
        .in("class_id", classIds);

      if (pupilsError) {
        return res.status(500).json({
          error: "Failed to fetch pupils",
          details: pupilsError.message,
        });
      }

      pupils = pupilsData || [];
    }

    const { data: attempts, error: attemptsError } = await supabase
      .from("smart_quiz_attempts")
      .select("quiz_id, pupil_id, status, score_percent")
      .in("quiz_id", quizIds);

    if (attemptsError) {
      return res.status(500).json({
        error: "Failed to fetch attempts",
        details: attemptsError.message,
      });
    }

    const submittedAttempts = (attempts || []).filter(
      (a) => a.status === "submitted"
    );

    const totalSubmissions = submittedAttempts.length;

    const overallAverageScore =
      totalSubmissions > 0
        ? Math.round(
            submittedAttempts.reduce(
              (sum, a) => sum + Number(a.score_percent || 0),
              0
            ) / totalSubmissions
          )
        : 0;

    const totalPossibleSubmissions = quizzes.length * pupils.length;
    const participationRate =
      totalPossibleSubmissions > 0
        ? Math.round((totalSubmissions / totalPossibleSubmissions) * 100)
        : 0;

    const subjectMap = {};

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

    for (const attempt of submittedAttempts) {
      const quiz = quizzes.find((q) => q.id === attempt.quiz_id);
      if (!quiz) continue;

      subjectMap[quiz.subject].submissions_count += 1;
      subjectMap[quiz.subject].total_score += Number(attempt.score_percent || 0);
    }

    const subjects = Object.values(subjectMap).map((item) => ({
      subject: item.subject,
      quizzes_count: item.quizzes_count,
      submissions_count: item.submissions_count,
      average_score:
        item.submissions_count > 0
          ? Math.round(item.total_score / item.submissions_count)
          : 0,
    }));

    subjects.sort((a, b) => b.average_score - a.average_score);

    const strongestSubject = subjects.length > 0 ? subjects[0] : null;
    const weakestSubject =
      subjects.length > 0 ? subjects[subjects.length - 1] : null;

    return res.json({
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
    });
  } catch (err) {
    console.error("Overall analytics error:", err);
    return res.status(500).json({
      error: "Internal server error",
      details: err.message,
    });
  }
});
// =========================
// START SERVER
// =========================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});