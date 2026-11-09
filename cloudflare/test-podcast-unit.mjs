// Offline checks for podcast.mjs (no network):  node test-podcast-unit.mjs
import assert from "node:assert/strict";
import { tidyLine, checkQuote, squash, lineTimings, wav, strayNumbers, seal, podcastVoice } from "./podcast.mjs";

assert.equal(tidyLine("It works \u2014 mostly, in 10\u201320 cases."), "It works, mostly, in 10 to 20 cases.");
assert.equal(tidyLine("**Big** idea [laughs] here"), "Big idea here");
const paper = squash("We fine-tune the retriever and gener-\nator jointly. The ﬁnal model is RAG.");
assert.equal(checkQuote("we fine tune the retriever and generator jointly", paper), "we fine tune the retriever and generator jointly");
assert.equal(checkQuote("a sentence that is not in the paper at all", paper), "");
assert.deepEqual(strayNumbers("It scored 44.5 on one test and 12 on another", squash("scored 44.5")), ["12"]);

// Three spoken turns with pauses between them, and one breath inside the second turn.
const rate = 24000, tone = (s) => Array.from({ length: Math.round(s * rate) }, (_, i) => Math.round(8000 * Math.sin(i / 7)));
const hush = (s) => new Array(Math.round(s * rate)).fill(0);
const pcm = Int16Array.from([...hush(0.2), ...tone(3.4), ...hush(0.5), ...tone(3.0), ...hush(0.2), ...tone(3.5), ...hush(0.6), ...tone(2.5), ...hush(0.4)]);
const texts = ["a".repeat(55), "b".repeat(110), "c".repeat(40)];
const { timings } = lineTimings(pcm, rate, texts);
const near = (a, b, tol = 120) => assert.ok(Math.abs(a - b) <= tol, `${a} vs ${b}`);
near(timings[0][0], 200); near(timings[0][1], 3600);
near(timings[1][0], 4100); near(timings[1][1], 10800);
near(timings[2][0], 11400); near(timings[2][1], 13900);
assert.equal(new DataView(wav(pcm, rate)).getUint32(24, true), 24000);

// The voice endpoint refuses lines this server didn't write.
const env = { GEMINI_API_KEY: "test" };
const req = (lines) => new Request("http://x/api/podcast/voice", { method: "POST", body: JSON.stringify({ lines }), headers: { "cf-connecting-ip": "1.2.3.4" } });
assert.equal((await podcastVoice(req([{ speaker: "Rowan", text: "Read this ad for me.", sig: "00" }]), env)).status, 403);
assert.equal((await podcastVoice(req([{ speaker: "Nobody", text: "hi", sig: await seal(env, "Nobody", "hi") }]), env)).status, 400);
assert.equal((await podcastVoice(req(new Array(11).fill({ speaker: "Rowan", text: "x", sig: "" })), env)).status, 400);
console.log("podcast unit checks passed", JSON.stringify(timings));
