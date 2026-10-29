// Paper Tree explainer. The Mac app posts {text, context, mode}; we ask Gemini and return {text}.
// The Gemini key lives only here, in the GEMINI_API_KEY environment variable on Netlify.

const MODEL = process.env.GEMINI_MODEL || "gemini-flash-latest";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

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
  "You are Paper Tree, a friendly guide who explains hard reading to a curious high school student.",
  "Explain only the highlighted text. Use the surrounding context to pick the right meaning, but do not summarize the whole passage.",
  "Write plain text only: no markdown, no bullet points, no headings, no asterisks, no emoji.",
  "Do not use em dashes or en dashes. Use commas or periods instead.",
  "Never invent citations, numbers, or facts that are not implied by the text. If the highlight is too short or unclear to explain, say so in one sentence and suggest highlighting the full sentence.",
  "Do not start with phrases like 'Sure' or 'Great question'. Start with the explanation.",
].join(" ");

const MODE_RULES = {
  plain: "Explain it in plain words a high school student would understand. Use at most 2 short sentences and under 45 words total. Define any jargon you use.",
  simpler: "Explain it as simply as possible, like to a curious 12 year old. Use under 30 words. One everyday comparison is fine if it helps.",
  detail: "Give a fuller explanation in under 90 words: what it means and why it matters in this context. Keep it readable for a high school student.",
};

const MAX_TOKENS = { plain: 160, simpler: 110, detail: 260 };

function clientIp(req, context) {
  return context?.ip || req.headers.get("x-nf-client-connection-ip") || req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
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

export default async (req, context) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: HEADERS });
  if (req.method !== "POST") return json(405, { error: "Use POST." });

  const key = process.env.GEMINI_API_KEY;
  if (!key) return json(500, { error: "The server is missing GEMINI_API_KEY." });

  const appToken = process.env.APP_TOKEN;
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

  const prompt =
    `${MODE_RULES[mode]}\n\n` +
    `Highlighted text:\n"""${text}"""\n\n` +
    (ctx ? `Surrounding context (for meaning only):\n"""${ctx}"""\n` : "No surrounding context was available.\n");

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20_000);
  try {
    const r = await fetch(GEMINI_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      signal: controller.signal,
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM }] },
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
          maxOutputTokens: MAX_TOKENS[mode],
          thinkingConfig: { thinkingBudget: 0 },
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
    return json(200, { text: tidy(out), mode, model: MODEL });
  } catch (e) {
    const timedOut = e?.name === "AbortError";
    return json(timedOut ? 504 : 502, { error: timedOut ? "The AI took too long. Try again." : "Could not reach the AI service." });
  } finally {
    clearTimeout(timer);
  }
};

export const config = { path: "/api/explain" };
