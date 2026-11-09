// Paper podcasts: two hosts talk one paper through, in plain words.
//
//   POST /api/podcast/script  {title, authors?, year?, text, source?, take?}
//     Gemini writes the conversation as JSON lines: {speaker, text, quote, section, sig}.
//     `quote` is a short span copied from the paper (checked here, blanked if it isn't really there),
//     so the app can light up the passage each line is about. `sig` seals each line so the voice
//     endpoint only ever reads scripts this server wrote.
//
//   POST /api/podcast/voice   {lines: [{speaker, text, sig}]}   (one part, up to 10 lines)
//     Gemini multi-speaker TTS reads the part. Returns audio/wav (24 kHz mono 16-bit) and, in the
//     X-Podcast-Timings header, [startMs, endMs] for every line, found by matching the pauses
//     between turns to where each line should fall by length.
//
// The app asks for the script, then records the parts a few at a time, so it can show real progress
// and each request stays small. The Gemini key never leaves the server.

export const HOSTS = {
  Juniper: { voice: "Aoede", style: "curious, warm and friendly, a little playful" },
  Rowan: { voice: "Charon", style: "calm, clear and kind, like a good teacher" },
};
const SPEAKERS = Object.keys(HOSTS);

const SCRIPT_MODELS = ["gemini-3.5-flash", "gemini-3-flash-preview", "gemini-flash-latest"];
const TTS_MODELS = ["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts", "gemini-3.1-flash-tts-preview"];
const SCRIPT_TIMEOUT_MS = 110_000;
const VOICE_TIMEOUT_MS = 90_000;
const MAX_PAPER_CHARS = 60_000;
const MAX_SCRIPT_BODY = 260_000;
const MAX_VOICE_BODY = 24_000;
const MAX_PART_LINES = 10;
const MAX_PART_CHARS = 3_600;
const RATE = 24_000; // samples a second, mono, 16-bit

const HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-Paper-Tree-Token",
  "Access-Control-Expose-Headers": "X-Podcast-Timings, X-Podcast-Model",
};
const json = (status, body) => new Response(JSON.stringify(body), { status, headers: HEADERS });

// MARK: Rate limits (best effort, per instance, like the other endpoints)

const buckets = new Map();
export function limited(key, max, windowMs) {
  const now = Date.now();
  const list = (buckets.get(key) || []).filter((t) => now - t < windowMs);
  list.push(now);
  buckets.set(key, list);
  if (buckets.size > 5000) buckets.clear();
  return list.length > max;
}
const ipOf = (req) => req.headers.get("cf-connecting-ip") || req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";

// MARK: Text helpers

const clean = (s, max) => String(s ?? "")
  .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, " ")
  .replace(/\s+/g, " ").trim().slice(0, max);

/// No em or en dashes, no markdown, no stage directions in brackets.
export function tidyLine(s) {
  return String(s ?? "")
    .replace(/(\d)\s*[\u2013\u2014]\s*(\d)/g, "$1 to $2")
    .replace(/\s*[\u2014\u2013]\s*/g, ", ")
    .replace(/\s+-{2,}\s+|\s+-\s+/g, ", ")
    .replace(/\*\*?|__|`|^#+\s*/gm, "")
    .replace(/\[[^\]]{0,40}\]|\((?:laughs?|sighs?|pause)\)/gi, "")
    .replace(/,\s*,/g, ",").replace(/\s+([,.?!])/g, "$1").replace(/\s+/g, " ")
    .trim();
}

/// For matching a quote against PDF text: letters and digits only, lowercased, line-end hyphens joined.
export function squash(s) {
  return String(s ?? "")
    .replace(/(\w)-\s*\n\s*(\w)/g, "$1$2")
    .normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
    .replace(/ﬁ/g, "fi").replace(/ﬂ/g, "fl")
    .toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

/// Keeps the quote only if it is really in the paper; otherwise tries its first words, then gives up.
export function checkQuote(quote, squashedPaper) {
  const q = clean(quote, 400).replace(/^["'\u201C\u2018]+|["'\u201D\u2019]+$/g, "");
  if (q.length < 12) return "";
  if (squashedPaper.includes(squash(q))) return q;
  const words = q.split(" ");
  for (const n of [12, 9, 7]) {
    if (words.length <= n) continue;
    const head = words.slice(0, n).join(" ");
    if (squashedPaper.includes(squash(head))) return head;
  }
  return "";
}

/// Numbers in a line that never appear in the paper (a sign of an invented figure).
export function strayNumbers(text, squashedPaper, extra = "") {
  const hay = " " + squashedPaper + " " + squash(extra) + " ";
  return (String(text).match(/\d+(?:[.,]\d+)?/g) || [])
    .map((n) => n.replace(/,/g, ""))
    .filter((n) => n.length > 1 || false)
    .filter((n) => !hay.includes(" " + squash(n) + " ") && !hay.includes(squash(n)));
}

// MARK: Sealing lines, so the voice endpoint only reads what the script endpoint wrote

let sealKey = null;
async function key(env) {
  if (sealKey) return sealKey;
  const secret = env.PODCAST_SECRET || env.GEMINI_API_KEY || "paper-tree";
  sealKey = await crypto.subtle.importKey("raw", new TextEncoder().encode("podcast-v1:" + secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return sealKey;
}
export async function seal(env, speaker, text) {
  const mac = await crypto.subtle.sign("HMAC", await key(env), new TextEncoder().encode(speaker + "\n" + text));
  return [...new Uint8Array(mac).slice(0, 12)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha(parts) {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(JSON.stringify(parts)));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// MARK: Gemini

class Fail extends Error { constructor(status, msg) { super(msg); this.status = status; } }

async function gemini(env, url, body, signal) {
  const r = await fetch(url, {
    method: "POST", signal, body: JSON.stringify(body),
    headers: { "Content-Type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
  });
  if (!r.ok) {
    const detail = await r.text().catch(() => "");
    console.error("Gemini", url.split("/").pop(), r.status, detail.slice(0, 300));
    throw new Fail(r.status, detail.slice(0, 200));
  }
  return r.json();
}

/// Tries each model in turn; a busy or missing model falls through to the next.
async function firstThatWorks(models, run) {
  let last;
  for (const m of models) {
    try { return await run(m); } catch (e) {
      last = e;
      if (e?.name === "AbortError") throw e;
      if (e?.status && ![404, 429, 500, 502, 503, 504].includes(e.status) && !(e instanceof SyntaxError) && !e.retry) throw e;
    }
  }
  throw last || new Fail(502, "no model answered");
}

const SCRIPT_SCHEMA = {
  type: "OBJECT",
  properties: {
    title: { type: "STRING" },
    lines: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          speaker: { type: "STRING", enum: SPEAKERS },
          text: { type: "STRING" },
          quote: { type: "STRING" },
          section: { type: "STRING" },
        },
        required: ["speaker", "text", "quote", "section"],
        propertyOrdering: ["speaker", "text", "quote", "section"],
      },
    },
  },
  required: ["title", "lines"],
  propertyOrdering: ["title", "lines"],
};

export function scriptPrompt({ title, authors, year, text, abstractOnly }) {
  return [
    "Write a short podcast conversation about one research paper, for a curious high school student.",
    "Two hosts:",
    "Juniper is curious. She asks the questions a smart teenager would ask, says when something sounds confusing, and reacts honestly.",
    "Rowan explains. He uses plain words, small everyday comparisons, and only what the paper says.",
    "",
    "Shape:",
    "Open with Juniper asking a question that makes the topic feel worth caring about. Say the paper's title once, early, in a natural way.",
    "Then walk through: the question the authors asked, why it matters, what they did, what they found, and what is still uncertain or limited.",
    "End with a one or two sentence takeaway from Rowan and a short closing line from Juniper.",
    "30 to 42 lines, about 600 to 850 words in total. Each line is one to three sentences and under 45 words. Alternate speakers, and let Juniper sometimes rephrase what she heard so it lands.",
    "",
    "Rules:",
    "Only use facts, numbers, names and results that appear in the paper text below. Never invent numbers, citations, quotes, or people. If something is not in the text, say it is not covered or leave it out.",
    "Explain each technical term in plain words the first time it comes up. Talk like real people: use contractions, short sentences, and the odd 'huh' or 'okay, so' where it fits.",
    "Do not claim to be the authors or to have run the study. Do not use em dashes or en dashes. No markdown, no emoji, no stage directions, no sound effects.",
    "Avoid hype words like groundbreaking, revolutionary, game changer. Avoid filler like 'great question' and 'welcome back'.",
    abstractOnly ? "Only the abstract is available, so keep it shorter (about 20 to 26 lines) and say once that you only have the summary of the paper." : "",
    "",
    "For every line also give:",
    "quote: an exact span of 6 to 25 words copied character for character from the paper text that the line is about, or an empty string for lines that are not about a specific passage.",
    "section: a short label for where that is in the paper, like Abstract, Introduction, Methods, Results, Discussion, or empty.",
    "title: a short, plain episode title of at most 8 words.",
    "",
    `Paper title: ${title}`,
    authors ? `Authors: ${authors}` : "",
    year ? `Year: ${year}` : "",
    "",
    "Paper text:",
    text,
  ].filter((l) => l !== null).join("\n");
}

export async function writeScript(env, input, signal) {
  const body = {
    contents: [{ role: "user", parts: [{ text: scriptPrompt(input) }] }],
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 8192,
      responseMimeType: "application/json",
      responseSchema: SCRIPT_SCHEMA,
      thinkingConfig: { thinkingLevel: "low" },
    },
  };
  const models = env.PODCAST_SCRIPT_MODEL ? [env.PODCAST_SCRIPT_MODEL, ...SCRIPT_MODELS] : SCRIPT_MODELS;
  return firstThatWorks([...new Set(models)], async (model) => {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
    const data = await gemini(env, url, body, signal);
    const cand = data?.candidates?.[0];
    if (cand?.finishReason === "SAFETY" || data?.promptFeedback?.blockReason) throw new Fail(422, "blocked");
    const out = (cand?.content?.parts || []).filter((p) => !p.thought).map((p) => p.text || "").join("").trim();
    const parsed = JSON.parse(out.replace(/^```(?:json)?\s*|\s*```$/g, ""));
    if (!Array.isArray(parsed?.lines) || parsed.lines.length < 8) { const e = new Fail(502, "short script"); e.retry = true; throw e; }
    return { parsed, model };
  });
}

/// Cleans what the model wrote and checks it against the paper.
export async function finishScript(env, parsed, paperText, meta = "") {
  const squashed = squash(paperText);
  const lines = [];
  let stray = 0, quoted = 0;
  for (const l of parsed.lines) {
    const speaker = SPEAKERS.includes(l?.speaker) ? l.speaker : (lines.length % 2 ? "Rowan" : "Juniper");
    const text = tidyLine(clean(l?.text, 420));
    if (!text) continue;
    const quote = checkQuote(l?.quote, squashed);
    if (quote) quoted++;
    const nums = strayNumbers(text, squashed, meta);
    stray += nums.length;
    lines.push({ speaker, text, quote, section: clean(l?.section, 30), sig: await seal(env, speaker, text) });
  }
  return { title: tidyLine(clean(parsed.title, 80)) || "A paper, talked through", lines, checks: { quoted, strayNumbers: stray } };
}

export async function podcastScript(req, env, waitUntil) {
  if (limited(ipOf(req) + ":podcast-script", 4, 10 * 60_000)) return json(429, { error: "That's a lot of podcasts at once. Try again in a few minutes." });
  let body;
  try {
    const raw = await req.text();
    if (raw.length > MAX_SCRIPT_BODY) return json(413, { error: "That paper is too long to send." });
    body = JSON.parse(raw);
  } catch { return json(400, { error: "Body must be JSON." }); }
  const title = clean(body?.title, 300);
  const text = String(body?.text ?? "").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, " ").replace(/[ \t]+/g, " ").slice(0, MAX_PAPER_CHARS).trim();
  if (!title || text.length < 400) return json(400, { error: "There isn't enough of the paper's text to talk about." });
  const authors = (Array.isArray(body?.authors) ? body.authors : []).map((a) => clean(a, 80)).filter(Boolean).slice(0, 6).join(", ");
  const year = Number(body?.year) || "";
  const abstractOnly = body?.source === "abstract";
  const take = Math.max(0, Math.min(99, Number(body?.take) || 0));
  const cacheKey = "podcast-script-v1:" + await sha([title, text, take, abstractOnly]);
  if (env.EXPLAIN_CACHE) {
    try {
      const hit = await env.EXPLAIN_CACHE.get(cacheKey, { type: "json" });
      if (hit?.lines?.length) return json(200, { ...hit, cached: true });
    } catch (e) { console.error("KV read", String(e)); }
  }
  const outer = new AbortController();
  const timer = setTimeout(() => outer.abort(), SCRIPT_TIMEOUT_MS);
  try {
    const { parsed, model } = await writeScript(env, { title, authors, year, text, abstractOnly }, outer.signal);
    const script = await finishScript(env, parsed, title + "\n" + text, [title, authors, year].join(" "));
    if (script.lines.length < 8) return json(502, { error: "The script came back too short. Try again." });
    const result = { ...script, hosts: Object.fromEntries(SPEAKERS.map((s) => [s, s === "Juniper" ? "asks" : "explains"])), model };
    if (env.EXPLAIN_CACHE) {
      const p = env.EXPLAIN_CACHE.put(cacheKey, JSON.stringify(result), { expirationTtl: 60 * 60 * 24 * 30 }).catch(() => {});
      waitUntil?.(p);
    }
    return json(200, result);
  } catch (e) {
    return json(...failure(e));
  } finally {
    clearTimeout(timer);
  }
}

function failure(e) {
  if (e?.name === "AbortError") return [504, { error: "Writing the script took too long. Try again." }];
  if (e?.status === 429) return [503, { error: "The voice and writing models are busy right now. Try again in a minute." }];
  if (e?.status === 422) return [422, { error: "The model wouldn't talk about this paper." }];
  console.error("podcast", String(e?.message || e));
  return [502, { error: "Something went wrong making the podcast. Try again." }];
}

// MARK: Voices

/// The seconds Gemini asks us to wait after a 429, if it says.
export function retryAfter(e) {
  const m = /retry in ((?:\d+h)?(?:\d+m(?!s))?(?:\d+(?:\.\d+)?s)?)/i.exec(e?.message || "");
  if (!m || !m[1]) return 0;
  const part = (u) => Number(new RegExp("(\\d+(?:\\.\\d+)?)" + u).exec(m[1])?.[1] || 0);
  return part("h") * 3600 + part("m(?!s)") * 60 + part("s");
}

/// `model` keeps a whole episode in one voice model: the app sends back the model that read part one,
/// because two models read the same voice a little differently. Busy models get one patient retry.
export async function speak(env, lines, signal, model = "") {
  const input = [{
    type: "user_input",
    content: lines.map((l) => ({
      type: "text", text: l.text,
      annotations: [{ type: "speech_metadata", speaker: l.speaker, style: HOSTS[l.speaker].style }],
    })),
  }];
  const models = TTS_MODELS.includes(model) ? [model]
    : [...new Set(env.PODCAST_TTS_MODEL ? [env.PODCAST_TTS_MODEL, ...TTS_MODELS] : TTS_MODELS)];
  const once = async (model) => {
    const data = await gemini(env, "https://generativelanguage.googleapis.com/v1beta/interactions", {
      model, input,
      response_format: { type: "audio", mime_type: "audio/l16" },
      generation_config: { speech_config: { speakers: SPEAKERS.map((s) => ({ speaker: s, voice: HOSTS[s].voice })) } },
    }, signal);
    const audio = (data?.steps || []).filter((s) => s.type === "model_output")
      .flatMap((s) => s.content || []).filter((c) => c.type === "audio").pop();
    if (!audio?.data) { const e = new Fail(502, "no audio"); e.retry = true; throw e; }
    const bytes = Uint8Array.from(atob(audio.data), (c) => c.charCodeAt(0));
    const rate = Number(/rate=(\d+)/.exec(audio.mime_type || "")?.[1]) || RATE;
    return { pcm: new Int16Array(bytes.buffer, 0, bytes.length >> 1), rate, model };
  };
  return firstThatWorks(models, async (m) => {
    try { return await once(m); } catch (e) {
      const wait = retryAfter(e);
      if (e?.status !== 429 || models.length > 1 || !wait || wait > 25) throw e;
      await new Promise((r) => setTimeout(r, wait * 1000 + 300));
      return once(m);
    }
  });
}

/// Loudness per 10 ms window.
function envelope(pcm, rate) {
  const win = Math.round(rate / 100);
  const out = new Float32Array(Math.floor(pcm.length / win));
  for (let w = 0; w < out.length; w++) {
    let s = 0;
    for (let i = w * win, e = i + win; i < e; i++) s += pcm[i] * pcm[i];
    out[w] = Math.sqrt(s / win);
  }
  return out;
}

/// Where each line starts and ends, in ms. The model reads every turn in order with a pause between
/// turns, so the boundaries go in pauses. Which pauses: the set that makes every line's length closest
/// to what its word count predicts (found exactly, by dynamic programming), with a small preference for
/// longer pauses over the quick breaths inside a sentence.
export function lineTimings(pcm, rate, texts) {
  const env = envelope(pcm, rate);
  const peak = env.reduce((m, v) => Math.max(m, v), 1);
  const quiet = Math.max(180, peak * 0.035);
  let gaps = [];
  let run = -1;
  for (let i = 0; i <= env.length; i++) {
    const silent = i < env.length && env[i] < quiet;
    if (silent && run < 0) run = i;
    if (!silent && run >= 0) { if (i - run >= 12) gaps.push({ a: run, b: i }); run = -1; }
  }
  let first = 0, last = env.length;
  if (gaps.length && gaps[0].a === 0) first = gaps.shift().b;
  if (gaps.length && gaps[gaps.length - 1].b === env.length) last = gaps.pop().a;
  const n = texts.length;
  const weights = texts.map((t) => Math.max(8, t.length) + 12);
  const total = weights.reduce((a, b) => a + b, 0);
  const span = Math.max(1, last - first);
  const pauses = gaps.reduce((s, g) => s + (g.b - g.a), 0);
  const perWeight = Math.max(1, span - pauses * 0.6) / total; // 10 ms windows of speech per unit of text
  let bounds;
  if (n > 1 && gaps.length >= n - 1) {
    const m = gaps.length;
    const fit = (from, to, k) => { // cost of line k running from window `from` to window `to`
      const want = weights[k] * perWeight;
      const r = Math.max(1, to - from) / want;
      return Math.log(r) ** 2;
    };
    const bonus = (g) => -0.25 * Math.min(1, (g.b - g.a) / 60);
    // best[k][j]: lowest cost for lines 0..k with line k ending at gap j.
    const best = Array.from({ length: n - 1 }, () => new Float64Array(m).fill(Infinity));
    const from = Array.from({ length: n - 1 }, () => new Int32Array(m).fill(-1));
    for (let j = 0; j < m; j++) best[0][j] = fit(first, gaps[j].a, 0) + bonus(gaps[j]);
    for (let k = 1; k < n - 1; k++) {
      for (let j = k; j < m; j++) {
        for (let i = k - 1; i < j; i++) {
          if (best[k - 1][i] === Infinity) continue;
          const c = best[k - 1][i] + fit(gaps[i].b, gaps[j].a, k) + bonus(gaps[j]);
          if (c < best[k][j]) { best[k][j] = c; from[k][j] = i; }
        }
      }
    }
    let end = -1, cost = Infinity;
    for (let j = n - 2; j < m; j++) {
      const c = best[n - 2][j] + fit(gaps[j].b, last, n - 1);
      if (c < cost) { cost = c; end = j; }
    }
    if (end >= 0) {
      bounds = [];
      for (let k = n - 2, j = end; k >= 0; j = from[k][j], k--) bounds.unshift(gaps[j]);
    }
  }
  if (!bounds) { // too few pauses to go round: split by length alone
    bounds = [];
    let acc = 0;
    for (let k = 0; k < n - 1; k++) {
      acc += weights[k];
      const at = Math.round(first + span * acc / total);
      bounds.push({ a: at, b: at });
    }
  }
  const out = [];
  let start = first;
  for (let k = 0; k < n; k++) {
    const end = k < bounds.length ? bounds[k].a : last;
    out.push([start * 10, Math.max(start * 10 + 200, end * 10)]);
    if (k < bounds.length) start = bounds[k].b;
  }
  return { timings: out, first: first * 10, last: last * 10 };
}

export function wav(pcm, rate) {
  const data = pcm.length * 2;
  const buf = new ArrayBuffer(44 + data);
  const v = new DataView(buf);
  const str = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  str(0, "RIFF"); v.setUint32(4, 36 + data, true); str(8, "WAVE");
  str(12, "fmt "); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, rate, true); v.setUint32(28, rate * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true);
  str(36, "data"); v.setUint32(40, data, true);
  new Int16Array(buf, 44).set(pcm);
  return buf;
}

/// Trims the part to a short lead-in and tail so parts join with an even breath between them.
export function trimmed(pcm, rate, first, last) {
  const a = Math.max(0, Math.round((first - 120) * rate / 1000));
  const b = Math.min(pcm.length, Math.round((last + 260) * rate / 1000));
  return { pcm: pcm.subarray(a, b), shiftMs: a * 1000 / rate };
}

export async function podcastVoice(req, env) {
  if (limited(ipOf(req) + ":podcast-voice", 40, 10 * 60_000)) return json(429, { error: "That's a lot of recording at once. Try again in a few minutes." });
  let body;
  try {
    const raw = await req.text();
    if (raw.length > MAX_VOICE_BODY) return json(413, { error: "That part is too long." });
    body = JSON.parse(raw);
  } catch { return json(400, { error: "Body must be JSON." }); }
  const lines = (Array.isArray(body?.lines) ? body.lines : []).slice(0, MAX_PART_LINES + 1)
    .map((l) => ({ speaker: String(l?.speaker || ""), text: String(l?.text || ""), sig: String(l?.sig || "") }));
  if (!lines.length || lines.length > MAX_PART_LINES) return json(400, { error: `Send 1 to ${MAX_PART_LINES} lines.` });
  if (lines.reduce((n, l) => n + l.text.length, 0) > MAX_PART_CHARS) return json(413, { error: "That part is too long." });
  for (const l of lines) {
    if (!HOSTS[l.speaker] || !l.text.trim()) return json(400, { error: "Unknown speaker or empty line." });
    if (l.sig !== await seal(env, l.speaker, l.text)) return json(403, { error: "Those lines didn't come from this server's script." });
  }
  const outer = new AbortController();
  const timer = setTimeout(() => outer.abort(), VOICE_TIMEOUT_MS);
  try {
    const { pcm, rate, model } = await speak(env, lines, outer.signal, String(body?.model || ""));
    const { timings, first, last } = lineTimings(pcm, rate, lines.map((l) => l.text));
    const cut = trimmed(pcm, rate, first, last);
    const shifted = timings.map(([a, b]) => [Math.max(0, Math.round(a - cut.shiftMs)), Math.round(b - cut.shiftMs)]);
    return new Response(wav(cut.pcm, rate), {
      status: 200,
      headers: {
        ...HEADERS,
        "Content-Type": "audio/wav",
        "X-Podcast-Timings": JSON.stringify(shifted),
        "X-Podcast-Model": model,
      },
    });
  } catch (e) {
    if (e?.name === "AbortError") return json(504, { error: "Recording took too long. Try again." });
    if (e?.status === 429) {
      const wait = Math.ceil(retryAfter(e)) || 30;
      // A wait of hours means the model's daily allowance is used up. Name the next model, so the
      // app can record the whole episode again in that one voice instead of mixing two.
      if (wait > 120) {
        const i = TTS_MODELS.indexOf(String(body?.model || ""));
        const next = i >= 0 ? TTS_MODELS[i + 1] : undefined;
        return json(503, { error: "The voice model has used up its allowance for today.", exhausted: true, retryAfter: wait, next });
      }
      return json(503, { error: "The voice model is busy.", retryAfter: wait });
    }
    return json(...failure(e));
  } finally {
    clearTimeout(timer);
  }
}
