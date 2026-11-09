// Netlify mirror of the Cloudflare podcast endpoints (the Worker in cloudflare/ is the live backend).
// Same code: the logic lives in cloudflare/podcast.mjs. Netlify's synchronous functions stop after
// about 26 seconds, which a long paper's script can pass, so prefer the Worker for podcasts.
import { podcastScript, podcastVoice } from "../../../cloudflare/podcast.mjs";

const env = () => ({
  GEMINI_API_KEY: process.env.GEMINI_API_KEY,
  PODCAST_SECRET: process.env.PODCAST_SECRET,
  PODCAST_SCRIPT_MODEL: process.env.PODCAST_SCRIPT_MODEL,
  PODCAST_TTS_MODEL: process.env.PODCAST_TTS_MODEL,
});

export default async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type, X-Paper-Tree-Token" } });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Use POST." }), { status: 405 });
  const token = process.env.APP_TOKEN;
  if (token && req.headers.get("x-paper-tree-token") !== token) return new Response(JSON.stringify({ error: "Missing or wrong app token." }), { status: 401 });
  const path = new URL(req.url).pathname;
  return path.endsWith("/voice") ? podcastVoice(req, env()) : podcastScript(req, env());
};

export const config = { path: ["/api/podcast/script", "/api/podcast/voice"] };
