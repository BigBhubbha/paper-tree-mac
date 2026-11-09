// Local test for the podcast endpoints. Start the worker first:  npx wrangler dev --port 8787
// Then:  node test-podcast.mjs <paper.txt> "<title>" [outDir]
// Writes episode.wav and episode.json (script plus timings) to outDir, the same way the app assembles them.
import { readFile, writeFile, mkdir } from "node:fs/promises";

const [file, title, outDir = "./podcast-test"] = process.argv.slice(2);
const BASE = process.env.BASE || "http://127.0.0.1:8787";
const text = (await readFile(file, "utf8")).slice(0, 60000);
await mkdir(outDir, { recursive: true });

const t0 = Date.now();
const secs = () => ((Date.now() - t0) / 1000).toFixed(1) + "s";
const r = await fetch(BASE + "/api/podcast/script", {
  method: "POST", headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ title, text, take: Number(process.env.TAKE || 0) }),
});
const script = await r.json();
if (!r.ok) { console.error("script failed", r.status, script); process.exit(1); }
const words = script.lines.reduce((n, l) => n + l.text.split(/\s+/).length, 0);
console.log(`script ${secs()}  model=${script.model}  "${script.title}"  lines=${script.lines.length}  words=${words}  checks=${JSON.stringify(script.checks)}`);
const dashes = script.lines.filter((l) => /[\u2013\u2014]/.test(l.text)).length;
console.log("lines with em/en dashes:", dashes);

// Parts of up to 9 lines; part one first, so the rest can use the model that read it, recorded two at a time, like the app.
const parts = [];
for (let i = 0; i < script.lines.length; i += 9) parts.push(script.lines.slice(i, i + 9));
const results = new Array(parts.length);
let next = 0;
let model = process.env.MODEL || "";
async function worker(stop = parts.length) {
  while (next < stop) {
    const k = next++;
    const s = Date.now();
    let v;
    for (let attempt = 0; attempt < 5; attempt++) {
    v = await fetch(BASE + "/api/podcast/voice", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ lines: parts[k].map(({ speaker, text, sig }) => ({ speaker, text, sig })), model }),
    });
    if (v.status !== 503) break;
    const busy = await v.json();
    if (busy.exhausted) { console.error("voice model out of daily allowance; next model:", busy.next); process.exit(2); }
    const wait = busy.retryAfter || 30;
    console.log(`part ${k + 1} waiting ${wait}s for a busy voice model`);
    await new Promise((r) => setTimeout(r, wait * 1000));
    }
    if (!v.ok) { console.error("voice failed", k, v.status, v.bodyUsed ? "" : await v.text()); process.exit(1); }
    const buf = Buffer.from(await v.arrayBuffer());
    results[k] = { pcm: buf.subarray(44), timings: JSON.parse(v.headers.get("x-podcast-timings")), model: v.headers.get("x-podcast-model") };
    model ||= results[k].model;
    console.log(`part ${k + 1}/${parts.length} ${((Date.now() - s) / 1000).toFixed(1)}s  ${(buf.length / 48000).toFixed(1)}s audio  ${results[k].model}`);
  }
}
await worker(1);
await Promise.all([worker(), worker()]);

const gap = Buffer.alloc(Math.round(0.18 * 24000) * 2);
const chunks = [];
const lines = [];
let at = 0;
results.forEach((p, k) => {
  p.timings.forEach(([a, b], j) => lines.push({ ...parts[k][j], start: (at + a) / 1000, end: (at + b) / 1000 }));
  chunks.push(p.pcm, gap);
  at += (p.pcm.length + gap.length) / 48;
});
const pcm = Buffer.concat(chunks);
const head = Buffer.alloc(44);
head.write("RIFF", 0); head.writeUInt32LE(36 + pcm.length, 4); head.write("WAVE", 8); head.write("fmt ", 12);
head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22); head.writeUInt32LE(24000, 24);
head.writeUInt32LE(48000, 28); head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34); head.write("data", 36); head.writeUInt32LE(pcm.length, 40);
await writeFile(outDir + "/episode.wav", Buffer.concat([head, pcm]));
await writeFile(outDir + "/episode.json", JSON.stringify({ title: script.title, model: script.model, lines }, null, 2));
console.log(`done ${secs()}  episode ${(pcm.length / 48000 / 60).toFixed(2)} min  -> ${outDir}`);
