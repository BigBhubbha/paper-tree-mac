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
        body.update({"dry_multiplier": dry, "dry_base": 1.75, "dry_allowed_length": 2, "dry_penalty_last_n": 8192,
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


# ---- Report ----
def run_report(a):
    ts = json.load(open(TESTSET, encoding="utf-8"))
    notes = json.load(open(a.notes, encoding="utf-8")) if a.notes and os.path.exists(a.notes) else {}
    runs = [json.load(open(f, encoding="utf-8")) for f in a.results]
    order = {"gemini": 0, "4b": 1, "9b": 2, "2b": 3, "4b-old-prompts": 4, "2b-old-prompts": 5}
    for r in runs:
        r["label"] = r.get("label") or ("gemini" if r["engine"] == "gemini" else r["model"])
    runs.sort(key=lambda r: order.get(r["label"], 9))
    name = {"gemini": "Gemini (" + next((r["model"] for r in runs if r["engine"] == "gemini"), "") + ", via the Worker)",
            "4b": "Qwen 3.5 4B, new prompts", "9b": "Qwen 3.5 9B, new prompts", "2b": "Qwen 3.5 2B (CI sibling), new prompts",
            "4b-old-prompts": "Qwen 3.5 4B, old prompts", "2b-old-prompts": "Qwen 3.5 2B, old prompts"}
    real = [h for h in ts["highlights"] if not h.get("regression")]
    byid = {h["id"]: h for h in ts["highlights"]}

    def item(r, hid):
        return next((x for x in r["items"] if x["id"] == hid), None)

    def verdict(label, hid):
        return notes.get(label, {}).get(hid, {})

    summary = []
    for r in runs:
        xs = [item(r, h["id"]) for h in real]
        xs = [x for x in xs if x]
        if not xs:
            continue
        n = len(xs)
        flagged = sum(1 for x in xs if x["overlap"] >= RESTATING)
        vs = [verdict(r["label"], x["id"]).get("verdict", "") for x in xs]
        summary.append({"label": r["label"], "name": name.get(r["label"], r["label"]), "runner": r.get("runner", ""), "n": n,
                        "flagged": flagged, "avgOverlap": sum(x["overlap"] for x in xs) / n,
                        "avgWords": sum(x["words"] for x in xs) / n, "avgSeconds": sum(x["seconds"] for x in xs) / n,
                        "retried": sum(1 for x in xs if x.get("retried")),
                        "explains": vs.count("explains"), "partly": vs.count("partly"), "restates": vs.count("restates"),
                        "wrong": sum(1 for v in vs if v.startswith("error"))})
    os.makedirs(a.out, exist_ok=True)
    head = a.header.strip() + "\n\n" if a.header else ""
    md = ["# Paper Tree local reader: quality test", "", head.strip(), ""]
    md += ["## Summary (the 15 real highlights)", "",
           "| Model | Restating (overlap 0.5 or more) | Avg overlap | Avg words | Avg time per explanation | Guard retries | My read: explains / partly / restates / has an error |",
           "|---|---|---|---|---|---|---|"]
    for s_ in summary:
        md.append(f"| {s_['name']} | {s_['flagged']} of {s_['n']} ({100*s_['flagged']/s_['n']:.0f}%) | {s_['avgOverlap']:.2f} | {s_['avgWords']:.0f} | "
                  f"{s_['avgSeconds']:.1f} s ({s_['runner']}) | {s_['retried']} | {s_['explains']} / {s_['partly']} / {s_['restates']} / {s_['wrong']} |")
    md += ["", "Overlap is the share of an answer's content words that already appear in the highlight (stop words left out). "
           "It catches word-for-word restating, not a paraphrase in new words, so each answer also has my own short note.", ""]
    for h in ts["highlights"]:
        md += [f"## {h['id']}. {h['paper']}" + (" (regression check, not scored)" if h.get("regression") else ""), "",
               f"Source: {h['source']}  ", f"Mode: {h['mode']}  ", f"Highlight: \"{h['highlight']}\"", ""]
        for r in runs:
            x = item(r, h["id"])
            if not x:
                continue
            v = verdict(r["label"], h["id"])
            meta = f"overlap {x['overlap']:.2f}, {x['words']} words, {x['seconds']:.1f} s" + (", guard retried" if x.get("retried") else "")
            md.append(f"- **{name.get(r['label'], r['label'])}** ({meta}): {x['answer']}")
            if v:
                md.append(f"  - Note: {v.get('verdict', '')}. {v.get('note', '')}".rstrip())
        md.append("")
    pods = [r for r in runs if r.get("podcast")]
    if pods:
        md += ["## Podcast (21 lines, abstract only)", "", f"Paper: {ts['podcast']['paper']} ({ts['podcast']['source']})", ""]
        for r in pods:
            pc = r["podcast"]
            md += [f"### {name.get(r['label'], r['label'])}", "",
                   f"Title: {pc['title']}  ", f"{len(pc['lines'])} lines, {pc['words']} words, {pc['duplicateLines']} repeated lines, "
                   f"{pc['seconds']:.0f} s to write ({pc.get('promptTokens')} prompt tokens, {pc.get('tokensPerSecond')} tokens/s)", ""]
            md += [f"{i+1}. {l['speaker']}: {l['text']}" for i, l in enumerate(pc["lines"])]
            v = notes.get(r["label"], {}).get("podcast")
            if v:
                md += ["", f"Note: {v.get('note', '')}"]
            md.append("")
    open(os.path.join(a.out, "comparison.md"), "w", encoding="utf-8").write("\n".join(md).replace("\n\n\n", "\n\n"))

    # HTML side-by-side: the three engines that matter for shipping.
    main = [r for r in runs if r["label"] in ("gemini", "4b", "9b")]
    e = html.escape
    rows = []
    for h in ts["highlights"]:
        cells = []
        for r in main:
            x = item(r, h["id"])
            if not x:
                cells.append("<td class=na>not run</td>")
                continue
            v = verdict(r["label"], h["id"])
            vd = v.get("verdict", "")
            cls = "bad" if vd.startswith("error") or vd == "restates" or x["overlap"] >= RESTATING else ("mid" if vd == "partly" else "ok")
            cells.append(f"<td class={cls}><div>{e(x['answer'])}</div><div class=meta>overlap {x['overlap']:.2f} · {x['words']} words · {x['seconds']:.1f} s"
                         + (" · retried" if x.get("retried") else "") + "</div>"
                         + (f"<div class=note><b>{e(vd)}</b>. {e(v.get('note', ''))}</div>" if v else "") + "</td>")
        reg = " <span class=reg>regression check</span>" if h.get("regression") else ""
        rows.append(f"<tr><th><div class=pid>{h['id']} · {e(h['paper'])}{reg}</div><div class=hl>“{e(h['highlight'])}”</div><div class=meta>{h['mode']}</div></th>{''.join(cells)}</tr>")
    srows = "".join(f"<tr><td>{e(s_['name'])}</td><td>{s_['flagged']} of {s_['n']}</td><td>{s_['avgOverlap']:.2f}</td><td>{s_['avgWords']:.0f}</td>"
                    f"<td>{s_['avgSeconds']:.1f} s</td><td>{s_['explains']} / {s_['partly']} / {s_['restates']} / {s_['wrong']}</td></tr>" for s_ in summary)
    page = f"""<!doctype html><meta charset=utf-8><title>Paper Tree local reader quality</title>
<style>body{{font:13px -apple-system,Helvetica,Arial,sans-serif;margin:24px;color:#1d2a1f;background:#f6f2e9}}
table{{border-collapse:collapse;width:100%;margin-bottom:24px}}td,th{{border:1px solid #d6cfbf;padding:8px;vertical-align:top;text-align:left;background:#fffdf8}}
th{{width:22%}}.hl{{font-style:italic;margin:4px 0}}.meta{{color:#6b6b60;font-size:11px;margin-top:6px}}.note{{font-size:11.5px;margin-top:6px}}
td.bad{{background:#fbe9e5}}td.mid{{background:#fdf6df}}td.ok{{background:#eef6ea}}.pid{{font-weight:600}}.reg{{color:#9a5b00;font-weight:400}}
thead th{{background:#2f4a33;color:#fff}}</style>
<h1>Paper Tree local reader: quality test</h1><p>{e(a.header or '')}</p>
<table><thead><tr><th>Model</th><th>Restating</th><th>Avg overlap</th><th>Avg words</th><th>Avg time</th><th>Explains / partly / restates / error</th></tr></thead>{srows}</table>
<table><thead><tr><th>Highlight</th>{''.join(f'<th>{e(name.get(r["label"], r["label"]))}</th>' for r in main)}</tr></thead>{''.join(rows)}</table>"""
    open(os.path.join(a.out, "comparison.html"), "w", encoding="utf-8").write(page)
    json.dump(summary, open(os.path.join(a.out, "summary.json"), "w"), indent=1)
    print(json.dumps(summary, indent=1))


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
    rp = sub.add_parser("report")
    rp.add_argument("results", nargs="+")
    rp.add_argument("--notes", default=os.path.join(ROOT, "scripts", "local-ai-quality", "notes.json"))
    rp.add_argument("--header", default="")
    rp.add_argument("--out", required=True)
    a = p.parse_args()
    {"local": run_local, "gemini": run_gemini, "report": run_report}[a.cmd](a)


if __name__ == "__main__":
    main()
