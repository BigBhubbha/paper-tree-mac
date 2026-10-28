# Paper Tree explainer (Netlify)

The Mac app never holds an AI key. It sends your highlight here, and this one small function asks Gemini and sends back a plain explanation.

```
POST /api/explain
{ "text": "the highlight", "context": "nearby sentences (optional)", "mode": "plain" | "simpler" | "detail" }
-> 200 { "text": "explanation", "mode": "plain", "model": "gemini-2.5-flash" }
-> 4xx/5xx { "error": "friendly message" }
```

## Deploy it (about 10 minutes)

1. Get a Gemini key at https://aistudio.google.com/apikey. Keep it private. Never paste it in code, chat, or GitHub.
2. Put this `backend` folder in its own GitHub repo (or drag the folder onto https://app.netlify.com/drop).
3. On Netlify: Add new site, Import from GitHub, pick the repo. Build settings are read from `netlify.toml`, so leave them as they are.
4. Site configuration, Environment variables, Add a variable:
   - `GEMINI_API_KEY` = your key
   - Optional: `APP_TOKEN` = any long random phrase. If you set it, paste the same phrase into the Mac app's Settings under "App token".
5. Deploys, Trigger deploy. When it is live, your address is `https://YOUR-SITE.netlify.app/api/explain`.
6. In the Mac app: Settings, paste that address, Save, then Test it.

## Try it from Terminal

```
curl -s -X POST https://YOUR-SITE.netlify.app/api/explain \
  -H 'Content-Type: application/json' \
  -d '{"text":"stochastic process","context":"","mode":"plain"}'
```

## Local checks

- `node test-local.mjs` runs the function against a fake Gemini (no key, no network).
- `npx netlify-cli dev` serves it at `http://localhost:8888/api/explain` using a local `.env` with `GEMINI_API_KEY=...` (the `.env` file is git-ignored). The Mac app accepts `http://localhost` addresses for testing.

## Limits and safety

- Input caps: 1500 characters of highlight, 1800 of context, 12 KB per request.
- A light per-instance rate limit (20 requests a minute per IP). It is best effort, because serverless instances do not share memory. For real protection, set a spending or quota limit for the key in Google AI Studio.
- The address is public. Anyone who finds it can use your Gemini quota, which is why `APP_TOKEN` and a quota limit are worth setting. A token shipped inside an app can be extracted, so treat it as a speed bump, not a lock.
- Gemini free tier rate limits apply. Free tier requests may be used by Google to improve its products, so mention that in your privacy note if you share the app.
