// Paper Tree explainer. The Mac app posts {text, context, mode}; we ask Gemini and return {text}.
// The Gemini key lives only here, in the GEMINI_API_KEY environment variable on Netlify.

let ENV = {};
const MODEL_DEFAULT = "gemini-flash-lite-latest";
const geminiUrl = () => `https://generativelanguage.googleapis.com/v1beta/models/${ENV.GEMINI_MODEL || MODEL_DEFAULT}:generateContent`;

const MAX_BODY_BYTES = 12_000;
const MAX_TEXT = 1500;
const MAX_CONTEXT = 1800;
const MODES = new Set(["plain", "simpler", "detail"]);

// Best-effort per-instance rate limit (serverless instances do not share memory).
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 20;
const hits = new Map();

const HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Paper-Tree-Token",
};

const json = (status, body) => new Response(JSON.stringify(body), { status, headers: HEADERS });

const SYSTEM = [
  "You are Paper Tree, a friendly guide who explains hard reading. Unless told who the reader is, assume a curious high school student.",
  "Explain only the highlighted text. Use the surrounding context to pick the right meaning, but do not summarize the whole passage.",
  "Write plain text only: no markdown, no bullet points, no headings, no asterisks, no emoji.",
  "Do not use em dashes or en dashes. Use commas or periods instead.",
  "Never invent citations, numbers, or facts that are not implied by the text. A single word or short term is fine: define it and explain what it means here. Only if the highlight is a meaningless fragment (like \"of the\") should you say so in one sentence and suggest highlighting the full sentence.",
  "Do not start with phrases like 'Sure' or 'Great question'. Start with the explanation.",
].join(" ");

const MODE_RULES = {
  plain: "answer: explain it in plain words a high school student would understand, in at most 2 short sentences and under 40 words.",
  simpler: "answer: explain it as simply as possible, like to a curious 12 year old, in under 28 words. One everyday comparison is fine.",
  detail: "answer: a fuller explanation in under 80 words, covering what it means and why it matters in this context, readable for a high school student.",
};

const TERMS_RULE =
  "terms: 0 to 4 hard words or phrases that appear in the highlighted text and that a high school student might not know, " +
  "copied as they appear. For each, meaning is a plain definition under 10 words, with no period at the end. " +
  "Skip easy words. Use an empty list if nothing is hard.";

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    answer: { type: "STRING" },
    terms: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: { term: { type: "STRING" }, meaning: { type: "STRING" } },
        required: ["term", "meaning"],
      },
    },
  },
  required: ["answer", "terms"],
  propertyOrdering: ["answer", "terms"],
};

// Optional "who is reading" hints from the app (0.2.3+). Only known values are used.
const SCHOOL = {
  middle: "a middle school student",
  hs9: "a high school freshman", hs10: "a high school sophomore", hs11: "a high school junior", hs12: "a high school senior",
  ug1: "a first year college student", ug2: "a second year college student", ug3: "a third year college student",
  ug4: "a fourth year college student", grad: "a grad student", none: "an adult reader not in school",
};
const EXPERTISE = {
  beginner: "a curious beginner in science",
  classes: "someone who has taken some science classes",
  ra: "an undergrad researcher or research assistant",
  grad: "a grad student in science",
  pro: "a professional scientist or principal investigator",
};
const FIELDS = {
  biology: "biology", chemistry: "chemistry", physics: "physics", csai: "computer science and AI",
  medicine: "medicine", psychology: "psychology", earth: "earth and climate science", other: "other fields",
};
const LENGTH_SCALE = { shortest: 0.7, balanced: 1, thorough: 1.3 };
const BASE_WORDS = { plain: 40, simpler: 28, detail: 80 };

function readerNote(profile) {
  if (!profile || typeof profile !== "object") return { note: "", scale: 1, expert: false, novice: false };
  const who = [SCHOOL[profile.school], EXPERTISE[profile.expertise]].filter(Boolean);
  const fields = (Array.isArray(profile.fields) ? profile.fields : []).map((f) => FIELDS[f]).filter(Boolean).slice(0, 4);
  const expert = ["grad", "pro"].includes(profile.expertise) || profile.school === "grad";
  const novice = profile.expertise === "beginner" || ["middle", "hs9", "hs10"].includes(profile.school);
  let note = "";
  if (who.length) note += `The reader is ${who.join(", and ")}. `;
  if (fields.length) note += `They mostly read ${fields.join(", ")}. `;
  if (expert) note += "Use the standard terms of the field without defining basics, and focus on what is specific or surprising in this passage. ";
  else if (novice) note += "Use everyday words and avoid jargon entirely. ";
  else if (who.length) note += "Pitch the vocabulary at their level. ";
  return { note, scale: LENGTH_SCALE[profile.length] || 1, expert, novice };
}

function modeRule(mode, reader) {
  let rule = MODE_RULES[mode];
  if (reader.scale !== 1) rule = rule.replace(/under \d+ words/, `under ${Math.round(BASE_WORDS[mode] * reader.scale)} words`);
  if (reader.note) rule = rule.replace("a high school student", "this reader").replace("like to a curious 12 year old", "in the simplest everyday words");
  return rule;
}

const MAX_TOKENS = { plain: 400, simpler: 320, detail: 560 };

/// Parse Gemini's JSON reply. Falls back to treating the whole reply as the answer.
function parseStructured(out) {
  let answer = "";
  let terms = [];
  try {
    const obj = JSON.parse(out.replace(/^```(?:json)?\s*|\s*```$/g, ""));
    answer = String(obj?.answer ?? "");
    if (Array.isArray(obj?.terms)) {
      terms = obj.terms
        .map((t) => ({ term: clean(t?.term, 60), meaning: tidy(clean(t?.meaning, 120)).replace(/\.$/, "") }))
        .filter((t) => t.term && t.meaning)
        .slice(0, 4);
    }
  } catch {
    answer = out;
  }
  return { answer: tidy(answer), terms };
}

function clientIp(req, context) {
  return req.headers.get("cf-connecting-ip") || req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
}

function rateLimited(ip) {
  const now = Date.now();
  const list = (hits.get(ip) || []).filter((t) => now - t < WINDOW_MS);
  list.push(now);
  hits.set(ip, list);
  if (hits.size > 5000) hits.clear();
  return list.length > MAX_PER_WINDOW;
}

function clean(s, max) {
  return String(s ?? "")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, max);
}

function tidy(out) {
  return out
    .replace(/(\d)\s*[\u2013\u2014]\s*(\d)/g, "$1 to $2") // 10–20 becomes 10 to 20
    .replace(/\s*[\u2014\u2013]\s*/g, ", ")            // no em or en dashes
    .replace(/\*\*?|__|`|^#+\s*/gm, "")          // strip stray markdown
    .replace(/,\s*,/g, ",")
    .trim();
}

async function handle(req, context) {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: HEADERS });
  if (req.method !== "POST") return json(405, { error: "Use POST." });

  const key = ENV.GEMINI_API_KEY;
  if (!key) return json(500, { error: "The server is missing GEMINI_API_KEY." });

  const appToken = ENV.APP_TOKEN;
  if (appToken && req.headers.get("x-paper-tree-token") !== appToken) {
    return json(401, { error: "Missing or wrong app token." });
  }

  if (rateLimited(clientIp(req, context))) return json(429, { error: "Too many requests. Try again in a minute." });

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return json(413, { error: "That highlight is too long. Try a shorter piece." });

  let body;
  try { body = JSON.parse(raw); } catch { return json(400, { error: "Body must be JSON." }); }

  const text = clean(body?.text, MAX_TEXT);
  const ctx = clean(body?.context, MAX_CONTEXT);
  const mode = MODES.has(body?.mode) ? body.mode : "plain";
  if (!text) return json(400, { error: "Highlight some text first." });

  const reader = readerNote(body?.profile);
  const prompt =
    `Reply as JSON with "answer" and "terms".\n${reader.note ? reader.note + "\n" : ""}${modeRule(mode, reader)}\n${reader.expert ? TERMS_RULE.replace("0 to 4", "0 to 2").replace("a high school student", "this reader") : TERMS_RULE}\n\n` +
    `Highlighted text:\n"""${text}"""\n\n` +
    (ctx ? `Surrounding context (for meaning only):\n"""${ctx}"""\n` : "No surrounding context was available.\n");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20_000);
  try {
    const r = await fetch(geminiUrl(), {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      signal: controller.signal,
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM }] },
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
          maxOutputTokens: MAX_TOKENS[mode],
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
          thinkingConfig: { thinkingLevel: "minimal" },
        },
      }),
    });

    if (r.status === 429) return json(429, { error: "The AI is busy right now. Try again in a minute." });
    if (!r.ok) {
      const detail = await r.text().catch(() => "");
      console.error("Gemini error", r.status, detail.slice(0, 500));
      return json(502, { error: "The AI service had a problem. Try again soon." });
    }

    const data = await r.json();
    const cand = data?.candidates?.[0];
    const out = (cand?.content?.parts || []).map((p) => p.text || "").join("").trim();
    if (!out) {
      const blocked = cand?.finishReason === "SAFETY" || data?.promptFeedback?.blockReason;
      return json(502, { error: blocked ? "The AI declined to explain that one." : "The AI came back empty. Try again." });
    }
    const { answer, terms } = parseStructured(out);
    if (!answer) return json(502, { error: "The AI came back empty. Try again." });
    // "text" stays the plain answer so 0.2.2 and older apps keep working.
    return json(200, { text: answer, terms, mode, model: ENV.GEMINI_MODEL || MODEL_DEFAULT });
  } catch (e) {
    const timedOut = e?.name === "AbortError";
    return json(timedOut ? 504 : 502, { error: timedOut ? "The AI took too long. Try again." : "Could not reach the AI service." });
  } finally {
    clearTimeout(timer);
  }
};


export default {
  async fetch(req, env) {
    ENV = env;
    const url = new URL(req.url);
    if (url.pathname !== "/api/explain") return json(404, { error: "Not found." });
    return handle(req, {});
  },
};
