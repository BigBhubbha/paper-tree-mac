// Paper Tree explainer. The Mac app posts {text, context, mode, profile?, stream?}; we ask Gemini and
// return {text, terms, mode, model} as JSON, or as server-sent events when the app asks to stream.
// The Gemini key lives only here, in the GEMINI_API_KEY Worker secret.

let ENV = {};

// Models, fastest first. The pinned Flash Lite answers in about a second. If it is slow we also ask
// the next one (a "hedge") and use whichever answers first. Gemini sometimes returns a brief
// "high demand" 503, so the fast models get a second try after a short pause before we fall back
// to slower ones. If a pinned model is ever retired, the "latest" alias at the end keeps things
// working with no code change.
const FAST = ["gemini-3.1-flash-lite", "gemini-3.1-flash-lite-preview"];
const SLOW = ["gemini-3.5-flash", "gemini-flash-lite-latest"];
const HEDGE_MS = 2000;      // no first byte from a model by then: start the next one too
const RETRY_PAUSE_MS = 350; // breather before asking a model that just said "busy" again
const TOTAL_MS = 18_000;    // give up on the whole request after this
const CACHE_VERSION = "v1"; // bump to drop every cached answer
const CACHE_TTL_S = 60 * 60 * 24 * 30;
/// The order we try models in, as [model, pause before asking].
const plan = () => {
  const fast = [...new Set([ENV.GEMINI_MODEL, ENV.GEMINI_FALLBACK_MODEL, ...FAST].filter(Boolean))];
  return [...fast.map((m) => [m, 0]), ...fast.map((m) => [m, RETRY_PAUSE_MS]), ...SLOW.map((m) => [m, 0])];
};
const sleep = (ms, signal) => new Promise((resolve, reject) => {
  if (!ms) return resolve();
  const t = setTimeout(resolve, ms);
  signal?.addEventListener("abort", () => { clearTimeout(t); reject(new DOMException("Aborted", "AbortError")); }, { once: true });
});
const geminiUrl = (model, stream) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:${stream ? "streamGenerateContent?alt=sse" : "generateContent"}`;

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


const MAX_TOKENS = { plain: 400, simpler: 320, detail: 560 };

// MARK: Small caches. Repeat highlights (and flipping back to a mode you already saw) come back instantly.

const memo = new Map(); // per-isolate, newest last
const MEMO_MAX = 500;

function memoGet(k) {
  const v = memo.get(k);
  if (v) { memo.delete(k); memo.set(k, v); }
  return v;
}
function memoSet(k, v) {
  memo.set(k, v);
  if (memo.size > MEMO_MAX) memo.delete(memo.keys().next().value);
}

async function cacheKey(parts) {
  const bytes = new TextEncoder().encode(JSON.stringify(parts));
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return CACHE_VERSION + ":" + [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function cacheRead(key) {
  const hit = memoGet(key);
  if (hit) return hit;
  if (!ENV.EXPLAIN_CACHE) return null;
  try {
    const v = await ENV.EXPLAIN_CACHE.get(key, { type: "json", cacheTtl: 3600 });
    if (v?.text) { memoSet(key, v); return v; }
  } catch (e) { console.error("KV read", String(e)); }
  return null;
}

function cacheWrite(key, value, waitUntil) {
  memoSet(key, value);
  if (!ENV.EXPLAIN_CACHE) return;
  const p = ENV.EXPLAIN_CACHE.put(key, JSON.stringify(value), { expirationTtl: CACHE_TTL_S })
    .catch((e) => console.error("KV write", String(e)));
  waitUntil?.(p);
}

// MARK: Gemini calls

class GeminiError extends Error {
  constructor(status, detail = "", blocked = false) { super(`Gemini ${status}`); this.status = status; this.detail = detail; this.blocked = blocked; }
}

/// Runs attempts with hedging: the first starts now, the next starts if the current ones are
/// slower than HEDGE_MS or fail. The first attempt to succeed wins and the rest are cancelled.
function hedged(attempts, outer) {
  return new Promise((resolve, reject) => {
    const ctrls = [];
    let running = 0, settled = false, lastErr = null, timer = null;
    const finish = (fn, arg) => { if (settled) return; settled = true; clearTimeout(timer); fn(arg); };
    const startNext = () => {
      if (settled) return;
      const i = ctrls.length;
      if (i >= attempts.length) { if (running === 0) finish(reject, lastErr || new GeminiError(502)); return; }
      const c = new AbortController();
      ctrls.push(c);
      outer.addEventListener("abort", () => c.abort(), { once: true });
      running++;
      clearTimeout(timer);
      timer = setTimeout(startNext, HEDGE_MS);
      attempts[i](c.signal).then(
        (r) => {
          if (settled) { r?.cancel?.(); return; }
          ctrls.forEach((x, j) => { if (j !== i) x.abort(); });
          finish(resolve, { ...r, index: i });
        },
        (e) => {
          running--;
          lastErr = e;
          if (settled) return;
          // Content blocks would fail on every model, so stop there.
          if (e?.blocked || outer.aborted) { if (running === 0 || e?.blocked) finish(reject, e); return; }
          startNext();
        },
      );
    };
    startNext();
  });
}

function requestBody(prompt, mode) {
  return JSON.stringify({
    systemInstruction: { parts: [{ text: SYSTEM }] },
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.4,
      maxOutputTokens: MAX_TOKENS[mode],
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
      thinkingConfig: { thinkingLevel: "minimal" },
    },
  });
}

async function postGemini(model, body, signal, stream) {
  const r = await fetch(geminiUrl(model, stream), {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": ENV.GEMINI_API_KEY },
    signal,
    body,
  });
  if (!r.ok) {
    const detail = await r.text().catch(() => "");
    console.error("Gemini error", model, r.status, detail.slice(0, 300));
    throw new GeminiError(r.status, detail);
  }
  return r;
}

function candidateText(data) {
  const cand = data?.candidates?.[0];
  return (cand?.content?.parts || []).filter((p) => !p.thought).map((p) => p.text || "").join("");
}

function isBlocked(data) {
  return data?.candidates?.[0]?.finishReason === "SAFETY" || !!data?.promptFeedback?.blockReason;
}

/// Non-streaming attempt: resolves with the full raw JSON text from the model.
const wholeAttempt = ([model, pause], body) => async (signal) => {
  await sleep(pause, signal);
  const r = await postGemini(model, body, signal, false);
  const data = await r.json();
  const out = candidateText(data).trim();
  if (!out) throw new GeminiError(502, "", isBlocked(data));
  return { model, out };
};

/// Streaming attempt: resolves once the model has produced its first bit of text, handing back the reader.
const streamAttempt = ([model, pause], body) => async (signal) => {
  await sleep(pause, signal);
  const r = await postGemini(model, body, signal, true);
  const events = sseEvents(r.body);
  // Step by hand: a for-await that returns early would close the stream we hand back.
  while (true) {
    const { done, value: data } = await events.next();
    if (done) break;
    const piece = candidateText(data);
    if (piece) return { model, first: piece, events, cancel: () => events.return() };
    if (isBlocked(data)) { await events.return(); throw new GeminiError(502, "", true); }
  }
  throw new GeminiError(502);
};

/// Yields each JSON object from a Gemini SSE stream.
async function* sseEvents(stream) {
  const reader = stream.pipeThrough(new TextDecoderStream()).getReader();
  let buf = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += value;
      let i;
      while ((i = buf.search(/\r?\n\r?\n/)) >= 0) {
        const block = buf.slice(0, i);
        buf = buf.slice(i).replace(/^\r?\n\r?\n/, "");
        const data = block.split(/\r?\n/).filter((l) => l.startsWith("data:")).map((l) => l.slice(5).trimStart()).join("\n");
        if (data) { try { yield JSON.parse(data); } catch { /* skip */ } }
      }
    }
  } finally {
    reader.cancel().catch(() => {});
  }
}

/// Pulls the "answer" string out of partial JSON like {"answer": "Cells use li
function partialAnswer(raw) {
  const m = raw.match(/"answer"\s*:\s*"/);
  if (!m) return "";
  let s = raw.slice(m.index + m[0].length);
  let end = -1;
  for (let i = 0; i < s.length; i++) {
    if (s[i] === "\\") { i++; continue; }
    if (s[i] === '"') { end = i; break; }
  }
  if (end >= 0) s = s.slice(0, end);
  else s = s.replace(/\\(u[0-9a-fA-F]{0,3})?$/, ""); // drop a half-written escape
  try { return JSON.parse('"' + s + '"'); } catch { return ""; }
}

function errorFor(e) {
  if (e?.name === "AbortError" || e?.status === "timeout") return { status: 504, error: "The AI took too long. Try again." };
  if (e?.blocked) return { status: 502, error: "The AI declined to explain that one." };
  if (e?.status === 429) return { status: 429, error: "The AI is busy right now. Try again in a minute." };
  return { status: 502, error: "The AI service had a problem. Try again soon." };
}

async function handle(req, waitUntil) {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: HEADERS });
  // A cheap GET lets the app open (warm) its connection before the first highlight.
  if (req.method === "GET" || req.method === "HEAD") return json(200, { ok: true });
  if (req.method !== "POST") return json(405, { error: "Use POST." });

  if (!ENV.GEMINI_API_KEY) return json(500, { error: "The server is missing GEMINI_API_KEY." });

  const appToken = ENV.APP_TOKEN;
  if (appToken && req.headers.get("x-paper-tree-token") !== appToken) {
    return json(401, { error: "Missing or wrong app token." });
  }

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return json(413, { error: "That highlight is too long. Try a shorter piece." });

  let body;
  try { body = JSON.parse(raw); } catch { return json(400, { error: "Body must be JSON." }); }

  const text = clean(body?.text, MAX_TEXT);
  const ctx = clean(body?.context, MAX_CONTEXT);
  const mode = MODES.has(body?.mode) ? body.mode : "plain";
  const wantsStream = body?.stream === true || (req.headers.get("accept") || "").includes("text/event-stream");
  if (!text) return json(400, { error: "Highlight some text first." });

  const reader = readerNote(body?.profile);
  const prompt =
    `Reply as JSON with "answer" and "terms".\n${reader.note ? reader.note + "\n" : ""}${modeRule(mode, reader)}\n${reader.expert ? TERMS_RULE.replace("0 to 4", "0 to 2").replace("a high school student", "this reader") : TERMS_RULE}\n\n` +
    `Highlighted text:\n"""${text}"""\n\n` +
    (ctx ? `Surrounding context (for meaning only):\n"""${ctx}"""\n` : "No surrounding context was available.\n");

  const key = await cacheKey([MAX_TOKENS[mode], SYSTEM, prompt]);
  const cached = await cacheRead(key);
  if (cached) {
    const result = { ...cached, mode, cached: true };
    return wantsStream ? sseOnce(result) : json(200, result);
  }

  // Cached answers are free, so only fresh model calls count toward the per-minute limit.
  if (rateLimited(clientIp(req))) return json(429, { error: "Too many requests. Try again in a minute." });

  const geminiBody = requestBody(prompt, mode);
  const outer = new AbortController();
  const overall = setTimeout(() => outer.abort(), TOTAL_MS);

  if (!wantsStream) {
    try {
      const { model, out } = await hedged(plan().map((m) => wholeAttempt(m, geminiBody)), outer.signal);
      const { answer, terms } = parseStructured(out);
      if (!answer) return json(502, { error: "The AI came back empty. Try again." });
      const result = { text: answer, terms, mode, model };
      cacheWrite(key, result, waitUntil);
      // "text" stays the plain answer so 0.2.2 and older apps keep working.
      return json(200, result);
    } catch (e) {
      const { status, error } = errorFor(outer.signal.aborted ? { name: "AbortError" } : e);
      return json(status, { error });
    } finally {
      clearTimeout(overall);
    }
  }

  // Streaming: wait for the first words (so errors can still be plain JSON with a status),
  // then send "delta" events with the answer so far and a final "done" with the full result.
  let first;
  try {
    first = await hedged(plan().map((m) => streamAttempt(m, geminiBody)), outer.signal);
  } catch (e) {
    clearTimeout(overall);
    const { status, error } = errorFor(outer.signal.aborted ? { name: "AbortError" } : e);
    return json(status, { error });
  }

  const { readable, writable } = new TransformStream();
  const writer = writable.getWriter();
  const enc = new TextEncoder();
  const send = (event, data) => writer.write(enc.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));

  const pump = (async () => {
    let rawOut = first.first;
    let shown = "";
    const emit = async () => {
      const a = tidyPartial(partialAnswer(rawOut));
      if (a && a !== shown) { shown = a; await send("delta", { text: a }); }
    };
    try {
      await emit();
      for await (const data of first.events) {
        rawOut += candidateText(data);
        await emit();
      }
      const { answer, terms } = parseStructured(rawOut.trim());
      if (!answer) {
        await send("error", { status: 502, error: "The AI came back empty. Try again." });
      } else {
        const result = { text: answer, terms, mode, model: first.model };
        cacheWrite(key, result, waitUntil);
        await send("done", result);
      }
    } catch (e) {
      const { status, error } = errorFor(outer.signal.aborted ? { name: "AbortError" } : e);
      await send("error", { status, error }).catch(() => {});
    } finally {
      clearTimeout(overall);
      await writer.close().catch(() => {});
    }
  })();
  waitUntil?.(pump);

  return new Response(readable, { status: 200, headers: SSE_HEADERS });
}

const SSE_HEADERS = {
  ...HEADERS,
  "Content-Type": "text/event-stream; charset=utf-8",
  "Cache-Control": "no-store, no-transform",
  "X-Accel-Buffering": "no",
};

function sseOnce(result) {
  const body = `event: delta\ndata: ${JSON.stringify({ text: result.text })}\n\nevent: done\ndata: ${JSON.stringify(result)}\n\n`;
  return new Response(body, { status: 200, headers: SSE_HEADERS });
}

/// Like tidy(), for text that is still being written: never leaves a dangling comma or space.
function tidyPartial(s) {
  return tidy(s).replace(/[,\s]+$/, "");
}

// MARK: Trees. Paper lookup and suggestions come from Semantic Scholar; the tree's species comes from Gemini.

const S2 = "https://api.semanticscholar.org";
const PAPER_FIELDS = "paperId,title,authors,year,venue,abstract,openAccessPdf,externalIds,url,fieldsOfStudy,s2FieldsOfStudy";
const sleepMs = (ms) => new Promise((r) => setTimeout(r, ms));

/// Calls Semantic Scholar, with an API key if the Worker has one, retrying briefly when it is busy.
async function s2(path, init = {}) {
  const headers = { "Content-Type": "application/json", ...(ENV.S2_API_KEY ? { "x-api-key": ENV.S2_API_KEY } : {}) };
  for (let attempt = 0; attempt < 3; attempt++) {
    const r = await fetch(S2 + path, { ...init, headers, signal: AbortSignal.timeout(9000) });
    if (r.status === 429 || r.status >= 500) { await sleepMs(900 * (attempt + 1)); continue; }
    return r;
  }
  return new Response(null, { status: 503 });
}

function slimPaper(p) {
  if (!p?.paperId || !p?.title) return null;
  const arxiv = p.externalIds?.ArXiv;
  let pdf = p.openAccessPdf?.url || "";
  if (!/\.pdf($|\?)|arxiv\.org\/pdf|\/pdf\//i.test(pdf)) pdf = ""; // landing pages are not PDFs
  if (!pdf && arxiv) pdf = `https://arxiv.org/pdf/${arxiv}`;
  const fields = [...new Set([...(p.fieldsOfStudy || []), ...(p.s2FieldsOfStudy || []).map((f) => f.category)].filter(Boolean))];
  return {
    id: p.paperId,
    title: clean(p.title, 400).replace(/\.$/, ""),
    authors: (p.authors || []).slice(0, 6).map((a) => a.name).filter(Boolean),
    year: p.year || null,
    venue: clean(p.venue, 160),
    abstract: clean(p.abstract, 700),
    pdf,
    url: p.url || `https://www.semanticscholar.org/paper/${p.paperId}`,
    fields: fields.slice(0, 5),
  };
}

async function cached(key, ttl, waitUntil, make) {
  const k = await cacheKey([key]);
  const hit = await cacheRead(k);
  if (hit) return hit;
  const value = await make();
  if (value?.ok) cacheWrite(k, { ...value, text: "1" }, waitUntil);
  return value;
}

async function readJSON(req) {
  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) throw new Error("too big");
  return JSON.parse(raw);
}

async function lookupPaper(req, waitUntil) {
  let body;
  try { body = await readJSON(req); } catch { return json(400, { error: "Body must be JSON." }); }
  const title = clean(body?.title, 400).replace(/^["'\u201C]+|["'\u201D]+$/g, "");
  if (title.length < 4) return json(400, { error: "Highlight the paper's whole title first." });
  const result = await cached("s2-match:" + title.toLowerCase(), 0, waitUntil, async () => {
    let r = await s2(`/graph/v1/paper/search/match?query=${encodeURIComponent(title)}&fields=${PAPER_FIELDS}`);
    let paper = null;
    if (r.ok) paper = slimPaper((await r.json())?.data?.[0]);
    if (!paper) {
      r = await s2(`/graph/v1/paper/search?query=${encodeURIComponent(title)}&limit=1&fields=${PAPER_FIELDS}`);
      if (r.ok) paper = slimPaper((await r.json())?.data?.[0]);
    }
    if (!paper && r.status === 503) return { ok: false, busy: true };
    return { ok: !!paper, paper };
  });
  if (result.busy) return json(503, { error: "Semantic Scholar is busy. Try again in a moment." });
  if (!result.ok) return json(404, { error: "I couldn't find that title in Semantic Scholar." });
  return json(200, { paper: result.paper });
}

async function recommendPapers(req, waitUntil) {
  let body;
  try { body = await readJSON(req); } catch { return json(400, { error: "Body must be JSON." }); }
  const id = String(body?.paperId || "").replace(/[^A-Za-z0-9:._-]/g, "").slice(0, 80);
  if (!id) return json(400, { error: "Missing paperId." });
  const exclude = new Set((Array.isArray(body?.exclude) ? body.exclude : []).map(String));
  const limit = Math.max(1, Math.min(10, Number(body?.limit) || 4));
  const result = await cached("s2-rec:" + id, 0, waitUntil, async () => {
    const tries = [
      () => s2(`/recommendations/v1/papers/forpaper/${id}?limit=20&fields=${PAPER_FIELDS}`),
      () => s2(`/recommendations/v1/papers?limit=20&fields=${PAPER_FIELDS}`, { method: "POST", body: JSON.stringify({ positivePaperIds: [id] }) }),
      () => s2(`/recommendations/v1/papers/forpaper/${id}?from=all-cs&limit=20&fields=${PAPER_FIELDS}`),
    ];
    for (const t of tries) {
      const r = await t();
      if (!r.ok) continue;
      const papers = ((await r.json())?.recommendedPapers || []).map(slimPaper).filter(Boolean);
      if (papers.length) return { ok: true, papers };
    }
    return { ok: false, papers: [] };
  });
  const papers = (result.papers || []).filter((p) => !exclude.has(p.id)).slice(0, limit);
  return json(200, { papers });
}

const SPECIES = ["oak", "willow", "conifer", "flytrap", "alien", "coral"];
const TONES = ["sage", "moss", "olive", "rust", "plum", "teal", "ochre"];
const SPECIES_SCHEMA = {
  type: "OBJECT",
  properties: {
    species: { type: "STRING", enum: SPECIES },
    commonName: { type: "STRING" },
    latinName: { type: "STRING" },
    note: { type: "STRING" },
    leafTone: { type: "STRING", enum: TONES },
    vigor: { type: "NUMBER" },
    twist: { type: "NUMBER" },
    droop: { type: "NUMBER" },
  },
  required: ["species", "commonName", "latinName", "note", "leafTone", "vigor", "twist", "droop"],
  propertyOrdering: ["species", "commonName", "latinName", "note", "leafTone", "vigor", "twist", "droop"],
};

async function treeSpecies(req, waitUntil) {
  let body;
  try { body = await readJSON(req); } catch { return json(400, { error: "Body must be JSON." }); }
  const titles = (Array.isArray(body?.titles) ? body.titles : []).map((t) => clean(t, 200)).filter(Boolean).slice(0, 12);
  const fields = (Array.isArray(body?.fields) ? body.fields : []).map((t) => clean(t, 60)).filter(Boolean).slice(0, 10);
  if (!titles.length) return json(400, { error: "A tree needs at least one paper." });
  const prompt =
    "You name and design a drawn plant that stands for a reader's collection of research papers. " +
    "Pick the species whose character best fits the topics:\n" +
    "oak = broad, foundational, classic biology, ecology, history of science; willow = people, minds, society, psychology, education, the humanities; " +
    "conifer = rigorous and structured, mathematics, physics, engineering, statistics; flytrap = medicine, disease, immunology, infection, predators and parasites, pharmacology; " +
    "alien = computing, AI, space, quantum, anything futuristic; coral = chemistry, materials, oceans, climate, earth science.\n" +
    "commonName: a playful two or three word name for this particular plant, like \"Lantern-pod Transformer Tree\". latinName: a made-up binomial in Latin style. " +
    "note: one plain sentence under 18 words saying why this plant fits the papers. No em dashes. " +
    "leafTone: a color that suits the topics. vigor, twist, droop: numbers from 0 to 1 for how bushy, how twisty, how drooping the plant is.\n\n" +
    `Fields: ${fields.join(", ") || "unknown"}\nPaper titles:\n- ${titles.join("\n- ")}`;
  const key = await cacheKey(["species-v1", prompt]);
  const hit = await cacheRead(key);
  if (hit) return json(200, hit.species);
  const outer = new AbortController();
  const timer = setTimeout(() => outer.abort(), 15_000);
  try {
    const geminiBody = JSON.stringify({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 300, responseMimeType: "application/json", responseSchema: SPECIES_SCHEMA, thinkingConfig: { thinkingLevel: "minimal" } },
    });
    const { out, model } = await hedged(plan().map((m) => wholeAttempt(m, geminiBody)), outer.signal);
    const o = JSON.parse(out);
    const num = (v) => Math.max(0, Math.min(1, Number(v) || 0.5));
    const species = {
      species: SPECIES.includes(o.species) ? o.species : "oak",
      commonName: tidy(clean(o.commonName, 60)),
      latinName: tidy(clean(o.latinName, 60)),
      note: tidy(clean(o.note, 200)),
      leafTone: TONES.includes(o.leafTone) ? o.leafTone : "sage",
      vigor: num(o.vigor), twist: num(o.twist), droop: num(o.droop),
      model,
    };
    cacheWrite(key, { text: "1", species }, waitUntil);
    return json(200, species);
  } catch (e) {
    const { status, error } = errorFor(e);
    return json(status, { error });
  } finally {
    clearTimeout(timer);
  }
}

const ROUTES = {
  "/api/explain": handle,
  "/api/paper/lookup": lookupPaper,
  "/api/paper/recommend": recommendPapers,
  "/api/tree/species": treeSpecies,
};

export default {
  async fetch(req, env, ctx) {
    ENV = env;
    const url = new URL(req.url);
    const route = ROUTES[url.pathname];
    if (!route) return json(404, { error: "Not found." });
    const waitUntil = (p) => ctx.waitUntil(p);
    if (route === handle) return handle(req, waitUntil);
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: HEADERS });
    if (req.method !== "POST") return json(405, { error: "Use POST." });
    if (ENV.APP_TOKEN && req.headers.get("x-paper-tree-token") !== ENV.APP_TOKEN) return json(401, { error: "Missing or wrong app token." });
    if (rateLimited(clientIp(req))) return json(429, { error: "Too many requests. Try again in a minute." });
    return route(req, waitUntil);
  },
};
