// Offline test of the function logic with a fake Gemini. Run: node test-local.mjs
import handler from "./netlify/functions/explain.mjs";

process.env.GEMINI_API_KEY = "test-key-not-real";
let lastGeminiBody = null;
globalThis.fetch = async (url, opts) => {
  lastGeminiBody = JSON.parse(opts.body);
  if (opts.headers["x-goog-api-key"] !== "test-key-not-real") throw new Error("key header missing");
  return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: "**Stochastic** means random — like dice. Values range 10–20." }] } }] }), { status: 200 });
};

const call = (body, method = "POST", headers = {}) =>
  handler(new Request("https://x.test/api/explain", { method, headers: { "Content-Type": "application/json", ...headers }, body: method === "POST" ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined }), { ip: "1.2.3.4" });

const show = async (label, p) => { const r = await p; console.log(label, r.status, await r.text()); };

await show("ok      ", call({ text: "stochastic", context: "a stochastic process", mode: "plain" }));
console.log("prompt has mode rule:", lastGeminiBody.contents[0].parts[0].text.includes("under 120 words"));
await show("simpler ", call({ text: "stochastic", mode: "simpler" }));
await show("badmode ", call({ text: "stochastic", mode: "hack" }));
await show("empty   ", call({ text: "   " }));
await show("notjson ", call("{nope"));
await show("toolarge", call({ text: "a".repeat(20000) }));
await show("GET     ", call(null, "GET"));
process.env.APP_TOKEN = "s3";
await show("notoken ", call({ text: "x" }));
await show("token   ", call({ text: "x" }, "POST", { "X-Paper-Tree-Token": "s3" }));
