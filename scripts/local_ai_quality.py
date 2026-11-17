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


# ---- Number check (mirrors LocalWriter.Numbers) ----
UNITS = "zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen".split()
TENS = {"twenty":20,"thirty":30,"forty":40,"fifty":50,"sixty":60,"seventy":70,"eighty":80,"ninety":90}
WORDVAL = {w:i for i,w in enumerate(UNITS)}; WORDVAL.update(TENS)
# Number words an answer may not use unless the paper text does.
FLAG_WORDS = set(UNITS[3:]) | set(TENS) | {"hundred","thousand","million","billion","trillion","half","halves","third","thirds",
    "quarter","quarters","fifth","fifths","sixth","sixths","tenth","tenths","percent","twice","double","triple","doubled","tripled","quadrupled"}
ALLOWED_DIGITS = {"0","1"}
def _norm(s):
    s = s.lower().replace("\u2212","-")
    return re.sub(r"(?<=\d)[ ,\u2009\u202f\u00a0](?=\d{3}(?!\d))", "", s)
def numbers(s):
    return set(m.lstrip("0") or "0" for m in re.findall(r"(?<![a-z\d.])\d+(?:\.\d+)?", _norm(s)))
def words(s):
    return set(re.findall(r"[a-z]+", s.lower()))
def spelled(s):
    out=set()
    for m in re.finditer(r"\b(twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)[- ](one|two|three|four|five|six|seven|eight|nine)\b|\b([a-z]+)\b", s.lower()):
        if m.group(1): out.add(str(TENS[m.group(1)]+WORDVAL[m.group(2)]))
        elif m.group(3) in WORDVAL: out.add(str(WORDVAL[m.group(3)]))
    return out
# Scientific notation (1.7x10^-9, 1.7e-9, 10^-9) and rate-unit families for the number check.
_SCI = re.compile(
    r"(?<![a-z\d])(\d+(?:\.\d+)?)\s*[x×*]\s*10\s*(?:\^|\*\*)?\s*([−\-–]?)\s*(\d+)"
    r"|(?<![a-z\d])(\d+(?:\.\d+)?)[eE]([+\-−]?)(\d+)"
    r"|(?<![a-z\d])10\s*(?:\^|\*\*)\s*([−\-–]?)\s*(\d+)",
    re.I)
_TIMES = re.compile(r"(?<![a-z\d])(\d+(?:\.\d+)?)\s*times\s+(?:further|stronger|more|as)\b|\bhow many times\s+(?:further|stronger|more|as)\b|\btimes\s+(?:further|stronger|more)\s+from\b", re.I)
# Rate denominators: "per year", "/Mpc", "every kilometer", "kilometer of distance".
UNIT_FAM = {
    "megaparsec": "mpc", "megaparsecs": "mpc", "mpc": "mpc",
    "parsec": "pc", "parsecs": "pc", "kpc": "kpc",
    "kilometer": "km", "kilometers": "km", "kilometre": "km", "kilometres": "km", "km": "km",
    "meter": "m", "meters": "m", "metre": "m", "metres": "m",
    "mile": "mi", "miles": "mi",
    "millimeter": "mm", "millimeters": "mm", "millimetre": "mm", "millimetres": "mm", "mm": "mm",
    "centimeter": "cm", "centimeters": "cm", "cm": "cm",
    "year": "year", "years": "year", "yr": "year",
    "decade": "decade", "decades": "decade",
    "day": "day", "days": "day",
    "hour": "hour", "hours": "hour",
    "minute": "minute", "minutes": "minute",
    "second": "second", "seconds": "second",
}
UNIT_DIM = {
    "mpc": "distance", "pc": "distance", "kpc": "distance", "km": "distance", "m": "distance",
    "mi": "distance", "mm": "distance", "cm": "distance",
    "year": "time", "decade": "time", "day": "time", "hour": "time", "minute": "time", "second": "time",
}
_PER_UNIT = re.compile(
    r"(?:per|/|every|each)\s*([A-Za-z]+)|\b([A-Za-z]+)\s+of distance", re.I)


def sci_forms(s):
    """Canonical scientific-notation forms in s, like 1.7e-9, with the raw phrase."""
    out = []
    for m in _SCI.finditer(s.replace("\u2212", "-").replace("\u2013", "-")):
        if m.group(1) is not None:
            coeff, sign, exp, phrase = m.group(1), m.group(2) or "", m.group(3), m.group(0)
        elif m.group(4) is not None:
            coeff, sign, exp, phrase = m.group(4), m.group(5) or "", m.group(6), m.group(0)
        else:
            coeff, sign, exp, phrase = "1", m.group(7) or "", m.group(8), m.group(0)
        sign = "-" if sign in ("-", "−", "–") else ""
        out.append((f"{coeff}e{sign}{exp.lstrip('0') or '0'}", phrase.strip()))
    return out


def rate_denoms(s):
    """Rate-denominator unit families in s, as (family, phrase)."""
    t = s
    t = re.sub(r"\bMpc\b", " megaparsec ", t)
    t = re.sub(r"\bkpc\b", " kpc ", t, flags=re.I)
    t = re.sub(r"\bkm\b", " kilometer ", t, flags=re.I)
    out, seen = [], set()
    for m in _PER_UNIT.finditer(t):
        raw = (m.group(1) or m.group(2)).lower()
        fam = UNIT_FAM.get(raw)
        if not fam or fam in seen:
            continue
        seen.add(fam)
        out.append((fam, m.group(0).strip()))
    return out


def unsupported(answer, source):
    """Numbers, number words, scientific-notation probabilities, unit swaps, or 'N times further' the paper never uses."""
    src_n = numbers(source) | spelled(source); src_w = words(source) | ({"percent"} if "%" in source else set())
    bad = sorted(n for n in numbers(answer) if n not in src_n and n not in ALLOWED_DIGITS)
    bad += sorted(w for w in words(answer) if w in FLAG_WORDS and w not in src_w)
    src_sci = {form for form, _ in sci_forms(source)}
    for form, phrase in sci_forms(answer):
        if form not in src_sci and phrase not in bad:
            bad.append(phrase)
    src_den = {fam: ph for fam, ph in rate_denoms(source)}
    src_dims = {UNIT_DIM[f] for f in src_den}
    for fam, phrase in rate_denoms(answer):
        if fam not in src_den and UNIT_DIM.get(fam) in src_dims and phrase not in bad:
            bad.append(phrase)
    if re.search(r"standard deviation|\bsigma\b|\bσ\b", source, re.I) and "times" not in source.lower():
        for m in _TIMES.finditer(answer):
            phrase = m.group(0)
            if phrase not in bad:
                bad.append(phrase)
    return bad


SPAN_UNITS = ("year", "week", "day", "month", "hour", "minute", "decade", "second")
_SPAN_NUM = re.compile(
    r"(?<![a-z\d.])(\d+(?:[ ,\u2009\u202f\u00a0]\d{3})?(?:\.\d+)?)\s*-?\s*(" + "|".join(SPAN_UNITS) + r")s?\b",
    re.I)
_SPAN_SPELL = re.compile(
    r"\b((?:twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)[- ](?:one|two|three|four|five|six|seven|eight|nine)|"
    r"(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|"
    r"fifteen|sixteen|seventeen|eighteen|nineteen))\s*-?\s*(" + "|".join(SPAN_UNITS) + r")s?\b",
    re.I)


def time_spans(s):
    """Time spans in s as (normalized number, unit stem, display phrase), first mention only."""
    out, seen = [], set()
    for m in _SPAN_NUM.finditer(s):
        n = next(iter(numbers(m.group(1))), m.group(1))
        unit = m.group(2).lower()
        key = n + "|" + unit
        if key in seen:
            continue
        seen.add(key)
        out.append((n, unit, m.group(0).strip()))
    for m in _SPAN_SPELL.finditer(s.lower()):
        n = next(iter(spelled(m.group(1))), m.group(1))
        unit = m.group(2).lower()
        key = n + "|" + unit
        if key in seen:
            continue
        seen.add(key)
        out.append((n, unit, m.group(0).strip()))
    return out


def missing_spans(answer, highlight):
    """Time spans written in the highlight that the answer dropped."""
    ans_n = numbers(answer) | spelled(answer)
    ans_w = words(answer)
    miss = []
    for n, unit, phrase in time_spans(highlight):
        if n not in ans_n or (unit not in ans_w and unit + "s" not in ans_w):
            miss.append(phrase)
    return miss


# Reader profiles (mirrors ReaderNote in LocalWriter.swift)
SCHOOLS = {
    "middle": "a middle school student", "hs9": "a high school freshman", "hs10": "a high school sophomore",
    "hs11": "a high school junior", "hs12": "a high school senior", "ug1": "a first year college student",
    "ug2": "a second year college student", "ug3": "a third year college student", "ug4": "a fourth year college student",
    "grad": "a grad student", "none": "an adult reader not in school",
}
EXPERTISE = {
    "beginner": "a curious beginner in science", "classes": "someone who has taken some science classes",
    "ra": "an undergrad researcher or research assistant", "grad": "a grad student in science",
    "pro": "a professional scientist or principal investigator",
}
EXPERT_RE = re.compile(
    r"\b(ph\.? ?d|phd student|doctoral|postdoc|professor|faculty|principal investigator|research scientist|"
    r"staff scientist|grad(uate)? student|in grad(uate)? school|master'?s (student|degree)|physician|"
    r"medical doctor|work(ing)? as an? (scientist|researcher|chemist|biologist|physicist|engineer))\b", re.I)
NOVICE_RE = re.compile(
    r"\b(middle school|[5-8]th grade|grade [5-8]|year [5-8]|high school freshman|freshman in high school|"
    r"9th grade|beginner|new to (science|this|reading)|no science|not much science|little science|"
    r"never (took|taken|studied|done))\b", re.I)


def reader_note(school=None, expertise=None, fields=None, length=None):
    who, said = [], []
    if school and school in SCHOOLS:
        who.append(SCHOOLS[school])
    if expertise and expertise in EXPERTISE:
        who.append(EXPERTISE[expertise])
    expert = expertise in ("grad", "pro") or school == "grad" or bool(EXPERT_RE.search(" ".join(x for x in (school, expertise) if x and x not in SCHOOLS and x not in EXPERTISE)))
    novice = (not expert) and (expertise == "beginner" or school in ("middle", "hs9", "hs10") or bool(NOVICE_RE.search(" ".join(x for x in (school, expertise) if x and x not in SCHOOLS and x not in EXPERTISE))))
    n = ""
    if who:
        n += "The reader is " + ", and ".join(who) + ". "
    if expert:
        n += "Use the standard terms of the field without defining basics, and focus on what's specific or surprising in this passage. "
    elif novice:
        n += "Use everyday words and avoid jargon entirely. "
    elif who or said:
        n += "Pitch the vocabulary at their level. "
    return {"note": n.strip(), "scale": 1.0, "expert": expert, "novice": novice,
            "school": school, "expertise": expertise}


PROFILES = {
    "default": reader_note(),
    "beginner": reader_note(school="middle", expertise="beginner"),
    "grad": reader_note(school="grad", expertise="grad"),
}


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


def length_rule(mode, reader=None):
    reader = reader or PROFILES["default"]
    who = "a curious high school student" if not reader.get("note") else "this reader"
    words = int(round(BASE_WORDS[mode] * reader.get("scale", 1)))
    if mode == "plain":
        return f"Plain version: explain it in plain words {who} would understand, in at most 2 short sentences and under {words} words."
    if mode == "simpler":
        like = "like to a curious 12 year old" if not reader.get("note") else "in the simplest everyday words"
        return (f"Simpler: as simply as possible, {like}, under {words} words. Use simpler words, never different facts. "
                "Explain what a statistic shows and why it matters, without any probability, ratio or unit the paper doesn't give. "
                "One everyday comparison is fine if it keeps the paper's scale, quantities, time spans and conditions.")
    return f"More detail: a fuller explanation under {words} words, covering what it means and why it matters here, readable for {who}."


def explain_user(reader, length, context, highlight):
    return f'Reader: {reader}\nLength: {length}\nSurrounding text from the paper:\n"""{context}"""\nHighlighted:\n"""{highlight}"""'


RETRY_NOTE = res("explain-retry.txt").strip() if os.path.exists(os.path.join(RES, "explain-retry.txt")) else ""


def explain_prompt(text, context, mode, retry=False, bad_numbers=(), keep_spans=(), reader=None):
    reader = reader or PROFILES["default"]
    shots = []
    for e in json.loads(res("explain-examples.json")):
        terms = ", ".join("{\"term\": %s, \"meaning\": %s}" % (jlit(t["term"]), jlit(t["meaning"])) for t in e["reply"]["terms"])
        reply = "{\"answer\": %s, \"terms\": [%s]}" % (jlit(e["reply"]["answer"]), terms)
        shots.append((explain_user(e["reader"], e["length"], e["context"], e["highlight"]), reply))
    ctx = fence(context, 1800)
    who = "Not described. Assume a curious high school student." if not reader.get("note") else reader["note"]
    user = explain_user(who, length_rule(mode, reader), ctx if ctx else "(none)", fence(text, 1500))
    if retry:
        user += "\n" + RETRY_NOTE
        if bad_numbers:
            user += "\nNot in the paper, so leave out: " + ", ".join(bad_numbers) + "."
        if keep_spans:
            user += "\nThe highlight also gives these time spans, so keep them: " + ", ".join(keep_spans) + "."
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
def post(url, body, timeout=3600, headers=None, retries=0):
    h = {"Content-Type": "application/json"}
    h.update(headers or {})
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=h)
    last = None
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
            code = getattr(e, "code", None)
            if attempt >= retries or (code is not None and code not in (408, 429, 500, 502, 503, 504)):
                raise
            wait = min(30, 3 * (attempt + 1))
            print(f"retry in {wait}s after {code or type(e).__name__}", flush=True)
            time.sleep(wait)
            req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=h)
    raise last


def complete(server, prompt, grammar, n_predict, temperature, seed, repeat_penalty=1.05, dry=0.0, cache=True):
    body = {"prompt": prompt, "grammar": grammar, "n_predict": n_predict, "temperature": temperature,
            "top_k": 40, "top_p": 0.9, "min_p": 0.05, "repeat_penalty": repeat_penalty, "repeat_last_n": 64,
            "seed": seed, "cache_prompt": cache, "samplers": ["penalties", "dry", "top_k", "top_p", "min_p", "temperature"]}
    if dry > 0:
        body.update({"dry_multiplier": dry, "dry_base": 1.75, "dry_allowed_length": 2, "dry_penalty_last_n": 8192,
                     "dry_sequence_breakers": ["\n", ":", "\"", "*"]})
    t0 = time.time()
    r = post(server.rstrip("/") + "/completion", body)
    tm = r.get("timings", {})
    return r["content"], {"seconds": round(time.time() - t0, 1), "promptTokens": tm.get("prompt_n"),
                          "promptSeconds": round(tm.get("prompt_ms", 0) / 1000, 1), "cachedTokens": tm.get("cache_n"), "generatedTokens": tm.get("predicted_n"),
                          "tokensPerSecond": round(tm.get("predicted_per_second", 0), 2)}


def parse_answer(raw):
    try:
        r = json.loads(raw)
        return tidy(r.get("answer", "")), [t for t in r.get("terms", []) if t.get("term")]
    except Exception:
        m = re.search(r'"answer": "((?:[^"\\]|\\.)*)', raw)
        return (tidy(m.group(1)) if m else ""), []


def parse_list(s, allowed, default):
    if not s:
        return list(default)
    out = [x.strip() for x in s.split(",") if x.strip()]
    bad = [x for x in out if x not in allowed]
    if bad:
        raise SystemExit("unknown value(s): " + ", ".join(bad) + "; expected one of " + ", ".join(allowed))
    return out


def jobs(ts, modes, profiles, only=""):
    """Expand highlights across modes and reader profiles. Default (empty flags) keeps each item's own mode and the default profile."""
    only = [x for x in (only or "").split(",") if x]
    out = []
    for i, it in enumerate(ts["highlights"]):
        if only and it["id"] not in only:
            continue
        use_modes = modes if modes else [it["mode"]]
        use_profiles = profiles if profiles else ["default"]
        for mode in use_modes:
            for prof in use_profiles:
                rec_id = it["id"] if (mode == it["mode"] and prof == "default" and not modes and not profiles) else f"{it['id']}/{mode}/{prof}"
                out.append({**it, "id": rec_id, "base_id": it["id"], "mode": mode, "profile": prof, "seed": 1000 + i * 50 + (["plain", "simpler", "detail"].index(mode) * 3 + ["default", "beginner", "grad"].index(prof) if prof in ("default", "beginner", "grad") else 9)})
    return out


def score_answer(ans, highlight, src):
    ov = overlap(ans, highlight)
    return (ov >= RESTATING, len(unsupported(ans, src)), len(missing_spans(ans, highlight)), ov)


def run_local(a):
    ts = json.load(open(TESTSET, encoding="utf-8"))
    modes = parse_list(getattr(a, "modes", ""), ("plain", "simpler", "detail"), [])
    profiles = parse_list(getattr(a, "profiles", ""), tuple(PROFILES), [])
    out = {"engine": "local", "model": a.model, "label": a.label or a.model, "prompts": "old" if os.environ.get("PAPER_TREE_PROMPTS") else "new",
           "runner": a.runner, "modes": modes, "profiles": profiles, "items": [], "podcast": None}
    if a.out and os.path.exists(a.out):
        try:
            prev = json.load(open(a.out, encoding="utf-8"))
            if prev.get("items") and prev.get("model") == a.model:
                out["items"] = prev["items"]
        except Exception:
            pass
    done = {x["id"] for x in out["items"]}
    grammar = res("explain.gbnf")
    work = jobs(ts, modes, profiles, a.only)
    for n, it in enumerate(work, 1):
        if it["id"] in done:
            print(f"skip {it['id']}", flush=True)
            continue
        reader = PROFILES[it["profile"]]
        n_predict = 420 if it["mode"] == "detail" else 300
        src = it["highlight"] + "\n" + it["context"]
        raw, t = complete(a.server, explain_prompt(it["highlight"], it["context"], it["mode"], reader=reader), grammar, n_predict, 0.5, it["seed"])
        ans, terms = parse_answer(raw)
        first = {"answer": ans, "overlap": round(overlap(ans, it["highlight"]), 2), "unsupported": unsupported(ans, src),
                 "missingSpans": missing_spans(ans, it["highlight"]), **t}
        rec = {"id": it["id"], "base_id": it["base_id"], "mode": it["mode"], "profile": it["profile"], "first": first, "retried": False}
        if (first["overlap"] >= RESTATING or first["unsupported"] or first["missingSpans"]) and RETRY_NOTE and not a.no_guard:
            raw2, t2 = complete(a.server, explain_prompt(it["highlight"], it["context"], it["mode"], retry=True,
                                                         bad_numbers=first["unsupported"], keep_spans=first["missingSpans"], reader=reader),
                                grammar, n_predict, 0.5, 2000 + it["seed"])
            ans2, terms2 = parse_answer(raw2)
            rec["retried"] = True
            if ans2 and score_answer(ans2, it["highlight"], src) < score_answer(ans, it["highlight"], src):
                ans, terms = ans2, terms2
            t = {k: (round(t[k] + t2[k], 1) if k in ("seconds", "promptSeconds") else t2[k]) for k in t}
        rec.update({"answer": ans, "terms": terms, "overlap": round(overlap(ans, it["highlight"]), 2), "unsupported": unsupported(ans, src),
                    "missingSpans": missing_spans(ans, it["highlight"]), "words": len(ans.split()), **t})
        out["items"].append(rec)
        print(f"[{n}/{len(work)}] {it['id']} {t['seconds']}s cached={t.get('cachedTokens')} ov={rec['overlap']} nums={rec['unsupported']} spans={rec['missingSpans']} retried={rec['retried']}: {ans}", flush=True)
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
    modes = parse_list(getattr(a, "modes", ""), ("plain", "simpler", "detail"), [])
    profiles = parse_list(getattr(a, "profiles", ""), tuple(PROFILES), [])
    out = {"engine": "gemini", "model": "", "label": getattr(a, "label", "") or "gemini",
           "runner": "Paper Tree Worker (read-only)", "modes": modes, "profiles": profiles, "items": []}
    if a.out and os.path.exists(a.out):
        try:
            prev = json.load(open(a.out, encoding="utf-8"))
            if prev.get("items") and prev.get("engine") == "gemini":
                out["items"] = prev["items"]
                out["model"] = prev.get("model", "")
        except Exception:
            pass
    done = {x["id"] for x in out["items"]}
    work = jobs(ts, modes, profiles, getattr(a, "only", ""))
    for n, it in enumerate(work, 1):
        if it["id"] in done:
            print(f"skip {it['id']}", flush=True)
            continue
        body = {"text": it["highlight"][:1500], "context": it["context"][:1800], "mode": it["mode"]}
        reader = PROFILES[it["profile"]]
        if it["profile"] != "default":
            body["profile"] = {"school": reader.get("school"), "expertise": reader.get("expertise")}
        t0 = time.time()
        r = post(WORKER, body, timeout=120, headers={"User-Agent": "PaperTree-Mac/quality-test"}, retries=4)
        ans = tidy(r.get("text") or "")
        src = it["highlight"] + "\n" + it["context"]
        out["model"] = r.get("model", out["model"])
        rec = {"id": it["id"], "base_id": it["base_id"], "mode": it["mode"], "profile": it["profile"],
               "answer": ans, "terms": r.get("terms") or [], "overlap": round(overlap(ans, it["highlight"]), 2),
               "unsupported": unsupported(ans, src), "missingSpans": missing_spans(ans, it["highlight"]),
               "words": len(ans.split()), "seconds": round(time.time() - t0, 1), "retried": False}
        out["items"].append(rec)
        print(f"[{n}/{len(work)}] {it['id']}", rec["overlap"], ans, flush=True)
        json.dump(out, open(a.out, "w"), indent=1, ensure_ascii=False)
        time.sleep(1)
    json.dump(out, open(a.out, "w"), indent=1, ensure_ascii=False)


# ---- Report ----
def run_report(a):
    ts = json.load(open(TESTSET, encoding="utf-8"))
    notes = json.load(open(a.notes, encoding="utf-8")) if a.notes and os.path.exists(a.notes) else {}
    runs = [json.load(open(f, encoding="utf-8")) for f in a.results]
    order = {"gemini": 0, "4b": 1, "9b": 2, "4b-prev": 3, "9b-prev": 4, "2b": 5, "4b-old-prompts": 6, "2b-old-prompts": 7}
    for r in runs:
        r["label"] = r.get("label") or ("gemini" if r["engine"] == "gemini" else r["model"])
    runs.sort(key=lambda r: order.get(r["label"], 9))
    name = {"gemini": "Gemini (" + next((r["model"] for r in runs if r["engine"] == "gemini"), "") + ", via the Worker)",
            "4b": "Qwen 3.5 4B, new prompts", "9b": "Qwen 3.5 9B, new prompts", "2b": "Qwen 3.5 2B (CI sibling), new prompts",
            "4b-old-prompts": "Qwen 3.5 4B, old prompts", "2b-old-prompts": "Qwen 3.5 2B, old prompts",
            "4b-prev": "Qwen 3.5 4B, previous pass (run 44067176475)", "9b-prev": "Qwen 3.5 9B, previous pass (run 44067176475)"}
    real = [h for h in ts["highlights"] if not h.get("regression")]
    byid = {h["id"]: h for h in ts["highlights"]}

    def item(r, hid):
        return next((x for x in r["items"] if x["id"] == hid), None)

    def verdict(label, hid):
        return notes.get(label, {}).get(hid, {})

    def base_of(x):
        return x.get("base_id") or x["id"].split("/")[0]

    def real_items(r):
        xs = [x for x in r["items"] if not byid.get(base_of(x), {}).get("regression")]
        return xs

    summary = []
    for r in runs:
        xs = real_items(r)
        if not xs:
            continue
        n = len(xs)
        flagged = sum(1 for x in xs if x["overlap"] >= RESTATING)
        vs = [verdict(r["label"], x["id"]).get("verdict", "") for x in xs]
        def source(x):
            h = byid[base_of(x)]
            return h["highlight"] + "\n" + h["context"]
        summary.append({"label": r["label"], "name": name.get(r["label"], r["label"]), "runner": r.get("runner", ""), "n": n,
                        "flagged": flagged, "avgOverlap": sum(x["overlap"] for x in xs) / n,
                        "avgWords": sum(x["words"] for x in xs) / n, "avgSeconds": sum(x["seconds"] for x in xs) / n,
                        "retried": sum(1 for x in xs if x.get("retried")),
                        "numberFlags": sum(1 for x in xs if unsupported(x["answer"], source(x))),
                        "spanFlags": sum(1 for x in xs if x.get("missingSpans") or missing_spans(x["answer"], byid[base_of(x)]["highlight"])),
                        "explains": vs.count("explains"), "partly": vs.count("partly"), "restates": vs.count("restates"),
                        "wrong": sum(1 for v in vs if v.startswith("error"))})
    os.makedirs(a.out, exist_ok=True)
    head = a.header.strip() + "\n\n" if a.header else ""
    md = ["# Paper Tree local reader: quality test", "", head.strip(), ""]
    md += ["## Summary (real highlights, regression left out)", "",
           "| Model | n | Restating (overlap 0.5 or more) | Avg overlap | Avg words | Avg time per explanation | Guard retries | Numbers not in the paper (auto check) | Dropped time spans | My read: explains / partly / restates / has an error |",
           "|---|---|---|---|---|---|---|---|---|---|"]
    for s_ in summary:
        md.append(f"| {s_['name']} | {s_['n']} | {s_['flagged']} of {s_['n']} ({100*s_['flagged']/s_['n']:.0f}%) | {s_['avgOverlap']:.2f} | {s_['avgWords']:.0f} | "
                  f"{s_['avgSeconds']:.1f} s ({s_['runner']}) | {s_['retried']} | {s_['numberFlags']} of {s_['n']} | {s_.get('spanFlags', 0)} of {s_['n']} | {s_['explains']} / {s_['partly']} / {s_['restates']} / {s_['wrong']} |")
    md += ["", "Overlap is the share of an answer's content words that already appear in the highlight (stop words left out). "
           "It catches word-for-word restating, not a paraphrase in new words, so each answer also has my own short note.", ""]

    # Per-mode and per-profile breakdown when a run used more than one of either.
    def counts_for(run, pred):
        xs = [x for x in run["items"] if pred(x) and not byid.get(x.get("base_id") or x["id"].split("/")[0], {}).get("regression")]
        vs = [verdict(run["label"], x["id"]).get("verdict", "") for x in xs]
        n = len(xs)
        if not n:
            return None
        return {"n": n, "explains": vs.count("explains"), "partly": vs.count("partly"), "restates": vs.count("restates"),
                "wrong": sum(1 for v in vs if v.startswith("error")),
                "avgSeconds": sum(x.get("seconds") or 0 for x in xs) / n,
                "flagged": sum(1 for x in xs if x.get("overlap", 0) >= RESTATING),
                "numberFlags": sum(1 for x in xs if x.get("unsupported")),
                "spanFlags": sum(1 for x in xs if x.get("missingSpans"))}

    levels_used = any(x.get("mode") and x.get("profile") for r in runs for x in r.get("items") or [])
    if levels_used:
        md += ["## Counts by mode and by reader profile", ""]
        for axis, keys, title in (("mode", ("plain", "simpler", "detail"), "Mode"),
                                  ("profile", ("default", "beginner", "grad"), "Reader profile")):
            md += [f"### By {title.lower()}", "",
                   f"| {title} | Model | n | My read: explains / partly / restates / has an error | Avg time | Restating | Numbers not in the paper | Dropped time spans |",
                   "|---|---|---|---|---|---|---|---|"]
            for key in keys:
                for r in runs:
                    c = counts_for(r, lambda x, k=key, ax=axis: x.get(ax) == k or (ax == "mode" and not x.get(ax) and byid.get(x.get("base_id") or x["id"], {}).get("mode") == k))
                    if not c:
                        continue
                    md.append(f"| {key} | {name.get(r['label'], r['label'])} | {c['n']} | {c['explains']} / {c['partly']} / {c['restates']} / {c['wrong']} | {c['avgSeconds']:.1f} s | {c['flagged']} | {c['numberFlags']} | {c['spanFlags']} |")
            md.append("")
        md += ["### Mode and profile together", "",
               "| Mode | Profile | Model | n | My read: explains / partly / restates / has an error | Avg time |",
               "|---|---|---|---|---|---|"]
        for mode in ("plain", "simpler", "detail"):
            for prof in ("default", "beginner", "grad"):
                for r in runs:
                    c = counts_for(r, lambda x, m=mode, p=prof: x.get("mode") == m and x.get("profile") == p)
                    if not c:
                        continue
                    md.append(f"| {mode} | {prof} | {name.get(r['label'], r['label'])} | {c['n']} | {c['explains']} / {c['partly']} / {c['restates']} / {c['wrong']} | {c['avgSeconds']:.1f} s |")
        md.append("")
    def item_meta(x):
        extra = []
        if x.get("unsupported"):
            extra.append("nums " + ", ".join(x["unsupported"]))
        if x.get("missingSpans"):
            extra.append("dropped " + ", ".join(x["missingSpans"]))
        if x.get("retried"):
            extra.append("guard retried")
        meta = f"overlap {x['overlap']:.2f}, {x['words']} words, {x['seconds']:.1f} s"
        if extra:
            meta += ", " + ", ".join(extra)
        return meta

    if levels_used:
        for h in ts["highlights"]:
            md += [f"## {h['id']}. {h['paper']}" + (" (regression check, not scored)" if h.get("regression") else ""), "",
                   f"Source: {h['source']}  ", f"Highlight: \"{h['highlight']}\"", ""]
            for mode in ("plain", "simpler", "detail"):
                md += [f"### {h['id']} · {mode}", ""]
                for prof in ("default", "beginner", "grad"):
                    rid = f"{h['id']}/{mode}/{prof}"
                    md.append(f"**{prof}**")
                    for r in runs:
                        x = item(r, rid)
                        if not x:
                            continue
                        v = verdict(r["label"], rid)
                        md.append(f"- **{name.get(r['label'], r['label'])}** ({item_meta(x)}): {x['answer']}")
                        if v:
                            md.append(f"  - Note: {v.get('verdict', '')}. {v.get('note', '')}".rstrip())
                    md.append("")
    else:
        for h in ts["highlights"]:
            md += [f"## {h['id']}. {h['paper']}" + (" (regression check, not scored)" if h.get("regression") else ""), "",
                   f"Source: {h['source']}  ", f"Mode: {h['mode']}  ", f"Highlight: \"{h['highlight']}\"", ""]
            for r in runs:
                x = item(r, h["id"])
                if not x:
                    continue
                v = verdict(r["label"], h["id"])
                md.append(f"- **{name.get(r['label'], r['label'])}** ({item_meta(x)}): {x['answer']}")
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
    md_name = getattr(a, "name", "") or "comparison.md"
    open(os.path.join(a.out, md_name), "w", encoding="utf-8").write("\n".join(md).replace("\n\n\n", "\n\n"))

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
    l.add_argument("--modes", default="", help="comma list: plain,simpler,detail. Empty uses each item's own mode.")
    l.add_argument("--profiles", default="", help="comma list: default,beginner,grad. Empty uses default only.")
    g = sub.add_parser("gemini")
    g.add_argument("--out", required=True)
    g.add_argument("--only", default="")
    g.add_argument("--modes", default="")
    g.add_argument("--profiles", default="")
    g.add_argument("--label", default="")
    rp = sub.add_parser("report")
    rp.add_argument("results", nargs="+")
    rp.add_argument("--notes", default=os.path.join(ROOT, "scripts", "local-ai-quality", "notes.json"))
    rp.add_argument("--header", default="")
    rp.add_argument("--out", required=True)
    rp.add_argument("--name", default="comparison.md", help="markdown file name (use comparison-levels.md for a levels pass)")
    a = p.parse_args()
    {"local": run_local, "gemini": run_gemini, "report": run_report}[a.cmd](a)


if __name__ == "__main__":
    main()
