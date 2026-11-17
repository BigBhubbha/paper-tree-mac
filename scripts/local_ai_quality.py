#!/usr/bin/env python3
"""Paper Tree local reader quality test.

Builds the same prompts as LocalWriter.swift (system prompt, few-shot examples, chat format,
length rule, grammar, sampler settings, restatement guard) from Resources/LocalAI, sends them
to a llama.cpp server (llama-server, the same llama.cpp release the app links), and writes the
answers with timings and a restatement score.

  python3 scripts/local_ai_quality.py local --server http://127.0.0.1:8080 --model Qwen3.5-4B-Q4_K_M --out results-4b.json
  python3 scripts/local_ai_quality.py gemini --out results-gemini.json   (read-only calls to the app's Worker)
  python3 scripts/local_ai_quality.py report results-*.json --out design-previews/local-ai/quality
"""
import argparse, html, json, os, re, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.environ.get("PAPER_TREE_PROMPTS") or os.path.join(ROOT, "Resources", "LocalAI")
TESTSET = os.path.join(ROOT, "scripts", "local-ai-quality", "testset.json")
WORKER = "https://paper-tree-explain.papertree.workers.dev/api/explain"


def res(name):
    with open(os.path.join(RES, name), encoding="utf-8") as f:
        return f.read()


# ---- Restatement score (mirrors LocalWriter.Overlap) ----
STOP = set()
for line in open(os.path.join(ROOT, "Resources", "LocalAI", "overlap-stopwords.txt"), encoding="utf-8").read().splitlines():
    if not line.startswith("#"):
        STOP.update(line.split())


def content_words(s):
    out = set()
    for w in re.findall(r"[a-z0-9]+(?:\.[0-9]+)?", s.lower().replace("\u2019", "'")):
        if w in STOP:
            continue
        if len(w) > 3 and w.endswith("s") and not w.endswith("ss"):
            w = w[:-1]
        out.add(w)
    return out


def overlap(answer, highlight):
    """Share of the answer's content words that are already in the highlight (0 to 1)."""
    a, h = content_words(answer), content_words(highlight)
    return len(a & h) / len(a) if a else 1.0


RESTATING = 0.5  # LocalWriter.Overlap.restating


# ---- Prompt building (mirrors LocalPrompts / LocalWriter) ----
def fence(s, mx):
    t = s[:mx]
    for bad in ["<|im_start|>", "<|im_end|>", "<|endoftext|>", "<think>", "</think>"]:
        t = t.replace(bad, " ")
    t = t.replace('"""', '"')
    return "".join(" " if (ord(c) < 0x20 and c not in "\n\t") or ord(c) == 0x7F else c for c in t)


def chat(system, examples, user):
    p = "<|im_start|>system\n" + system.strip() + "<|im_end|>\n"
    for u, a in examples:
        p += "<|im_start|>user\n" + u + "<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n" + a + "<|im_end|>\n"
    return p + "<|im_start|>user\n" + user + "<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"


def jlit(s):
    return json.dumps(s, ensure_ascii=False)


BASE_WORDS = {"plain": 40, "simpler": 28, "detail": 80}


def length_rule(mode):  # no reader profile: scale 1, "a curious high school student"
    who, words = "a curious high school student", BASE_WORDS[mode]
    if mode == "plain":
        return f"Plain version: explain it in plain words {who} would understand, in at most 2 short sentences and under {words} words."
    if mode == "simpler":
        return f"Simpler: as simply as possible, like to a curious 12 year old, under {words} words. One everyday comparison is fine."
    return f"More detail: a fuller explanation under {words} words, covering what it means and why it matters here, readable for {who}."


def explain_user(reader, length, context, highlight):
    return f'Reader: {reader}\nLength: {length}\nSurrounding text from the paper:\n"""{context}"""\nHighlighted:\n"""{highlight}"""'


RETRY_NOTE = res("explain-retry.txt").strip() if os.path.exists(os.path.join(RES, "explain-retry.txt")) else ""


def explain_prompt(text, context, mode, retry=False):
    shots = []
    for e in json.loads(res("explain-examples.json")):
        terms = ", ".join("{\"term\": %s, \"meaning\": %s}" % (jlit(t["term"]), jlit(t["meaning"])) for t in e["reply"]["terms"])
        reply = "{\"answer\": %s, \"terms\": [%s]}" % (jlit(e["reply"]["answer"]), terms)
        shots.append((explain_user(e["reader"], e["length"], e["context"], e["highlight"]), reply))
    ctx = fence(context, 1800)
    user = explain_user("Not described. Assume a curious high school student.", length_rule(mode),
                        ctx if ctx else "(none)", fence(text, 1500))
    if retry:
        user += "\n" + RETRY_NOTE
    return chat(res("explain-system.txt"), shots, user)


def tidy(s):  # the parts of Tidy.line that matter for scoring
    t = re.sub(r"(\d)\s*[\u2013\u2014]\s*(\d)", r"\1 to \2", s)
    t = re.sub(r"\s*[\u2014\u2013]\s*", ", ", t)
    t = re.sub(r"\*\*?|__|`", "", t)
    return re.sub(r"\s+", " ", t).strip()


def podcast_grammar(lines):
    g = 'root ::= title "\\n"' + "".join(f' l{n} "\\n"' for n in range(1, lines + 1)) + "\n"
    for n in range(1, lines + 1):
        who = "Juniper" if n % 2 == 1 else "Rowan"
        g += f'l{n} ::= "{{\\"n\\": {n}, \\"speaker\\": \\"{who}\\", \\"text\\": " str ", \\"quote\\": " opt ", \\"section\\": " opt "}}"\n'
    return g + res("podcast.gbnf")


def podcast_prompt(p, source="abstract"):
    body = fence(p["text"], 22000)
    rule = "exactly 21 lines, about 400 words in total (roughly 3 minutes spoken). Say once that you only have a short summary of the paper."
    user = f"Length: {rule}\n\n"
    user += f"Paper title: {fence(p['paper'], 300)}\n"
    if p.get("authors"):
        user += f"Authors: {fence(', '.join(p['authors'][:6]), 300)}\n"
    if p.get("year"):
        user += f"Year: {p['year']}\n"
    user += f'\nPaper text:\n"""\n{body}\n"""'
    return chat(res("podcast-system.txt"), [], user), 21


# ---- Running ----
def post(url, body, timeout=3600, headers=None):
    h = {"Content-Type": "application/json"}
    h.update(headers or {})
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=h)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def complete(server, prompt, grammar, n_predict, temperature, seed, repeat_penalty=1.05, dry=0.0):
    body = {"prompt": prompt, "grammar": grammar, "n_predict": n_predict, "temperature": temperature,
            "top_k": 40, "top_p": 0.9, "min_p": 0.05, "repeat_penalty": repeat_penalty, "repeat_last_n": 64,
            "seed": seed, "cache_prompt": False, "samplers": ["penalties", "dry", "top_k", "top_p", "min_p", "temperature"]}
    if dry > 0:
        body.update({"dry_multiplier": dry, "dry_base": 1.75, "dry_allowed_length": 2, "dry_penalty_last_n": -1,
                     "dry_sequence_breakers": ["\n", ":", "\"", "*"]})
    t0 = time.time()
    r = post(server.rstrip("/") + "/completion", body)
    tm = r.get("timings", {})
    return r["content"], {"seconds": round(time.time() - t0, 1), "promptTokens": tm.get("prompt_n"),
                          "promptSeconds": round(tm.get("prompt_ms", 0) / 1000, 1), "generatedTokens": tm.get("predicted_n"),
                          "tokensPerSecond": round(tm.get("predicted_per_second", 0), 2)}


def parse_answer(raw):
    try:
        r = json.loads(raw)
        return tidy(r.get("answer", "")), [t for t in r.get("terms", []) if t.get("term")]
    except Exception:
        m = re.search(r'"answer": "((?:[^"\\]|\\.)*)', raw)
        return (tidy(m.group(1)) if m else ""), []


def run_local(a):
    ts = json.load(open(TESTSET, encoding="utf-8"))
    out = {"engine": "local", "model": a.model, "label": a.label or a.model, "prompts": "old" if os.environ.get("PAPER_TREE_PROMPTS") else "new", "runner": a.runner, "items": [], "podcast": None}
    grammar = res("explain.gbnf")
    for i, it in enumerate(ts["highlights"]):
        if a.only and it["id"] not in a.only.split(","):
            continue
        n_predict = 420 if it["mode"] == "detail" else 300
        raw, t = complete(a.server, explain_prompt(it["highlight"], it["context"], it["mode"]), grammar, n_predict, 0.5, 1000 + i)
        ans, terms = parse_answer(raw)
        first = {"answer": ans, "overlap": round(overlap(ans, it["highlight"]), 2), **t}
        rec = {"id": it["id"], "first": first, "retried": False}
        if first["overlap"] >= RESTATING and RETRY_NOTE and not a.no_guard:
            raw2, t2 = complete(a.server, explain_prompt(it["highlight"], it["context"], it["mode"], retry=True), grammar, n_predict, 0.5, 2000 + i)
            ans2, terms2 = parse_answer(raw2)
            rec["retried"] = True
            ov2 = overlap(ans2, it["highlight"])
            if ans2 and ov2 < first["overlap"]:
                ans, terms = ans2, terms2
            t = {k: (round(t[k] + t2[k], 1) if k in ("seconds", "promptSeconds") else t2[k]) for k in t}
        rec.update({"answer": ans, "terms": terms, "overlap": round(overlap(ans, it["highlight"]), 2),
                    "words": len(ans.split()), **t})
        out["items"].append(rec)
        print(f"{it['id']} {t['seconds']}s ov={rec['overlap']} retried={rec['retried']}: {ans}", flush=True)
        json.dump(out, open(a.out, "w"), indent=1, ensure_ascii=False)
    if not a.skip_podcast:
        prompt, count = podcast_prompt(ts["podcast"])
        raw, t = complete(a.server, prompt, podcast_grammar(count), count * 60 + 60, 0.7, 7, repeat_penalty=1.08, dry=0.8)
        lines = []
        title = ""
        for ln in raw.splitlines():
            try:
                j = json.loads(ln)
            except Exception:
                continue
            if "title" in j:
                title = j["title"]
            elif j.get("text"):
                lines.append({"speaker": j.get("speaker"), "text": tidy(j["text"])})
        texts = [l["text"].lower() for l in lines]
        out["podcast"] = {"title": title, "lines": lines, "duplicateLines": len(texts) - len(set(texts)),
                          "words": sum(len(l["text"].split()) for l in lines), **t}
        print(f"podcast {t['seconds']}s {len(lines)} lines", flush=True)
    json.dump(out, open(a.out, "w"), indent=1, ensure_ascii=False)


def run_gemini(a):
    ts = json.load(open(TESTSET, encoding="utf-8"))
    out = {"engine": "gemini", "model": "", "runner": "Paper Tree Worker (read-only)", "items": []}
    for it in ts["highlights"]:
        t0 = time.time()
        r = post(WORKER, {"text": it["highlight"][:1500], "context": it["context"][:1800], "mode": it["mode"]},
                 timeout=120, headers={"User-Agent": "PaperTree-Mac/quality-test"})
        ans = tidy(r.get("text") or "")
        out["model"] = r.get("model", out["model"])
        out["items"].append({"id": it["id"], "answer": ans, "terms": r.get("terms") or [], "overlap": round(overlap(ans, it["highlight"]), 2),
                             "words": len(ans.split()), "seconds": round(time.time() - t0, 1), "retried": False})
        print(it["id"], out["items"][-1]["overlap"], ans, flush=True)
        time.sleep(1)
    json.dump(out, open(a.out, "w"), indent=1, ensure_ascii=False)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    l = sub.add_parser("local")
    l.add_argument("--server", default="http://127.0.0.1:8080")
    l.add_argument("--model", required=True)
    l.add_argument("--runner", default="")
    l.add_argument("--out", required=True)
    l.add_argument("--only", default="")
    l.add_argument("--skip-podcast", action="store_true")
    l.add_argument("--no-guard", action="store_true")
    l.add_argument("--label", default="")
    g = sub.add_parser("gemini")
    g.add_argument("--out", required=True)
    a = p.parse_args()
    {"local": run_local, "gemini": run_gemini}[a.cmd](a)


if __name__ == "__main__":
    main()
