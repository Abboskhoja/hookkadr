"""Benchmark candidate on-device language models for Kadr AI on Uzbek tasks.

Runs each GGUF through ``llama-server`` (llama.cpp), asks the same Uzbek
product tasks, measures speed and scores the structured (JSON) tasks
automatically. Free-text answers are saved for human review.

Usage::

    uv run python -m hookkadr_ai.llm.bench --models data/llm/*.gguf
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import time
import urllib.request
from pathlib import Path

from ..paths import AI_ROOT

SYSTEM = (
    "Sen Kadr AI — HOOKKADR ilovasidagi video va rasm bo‘yicha yordamchisan. "
    "Faqat o‘zbek tilida (lotin yozuvi) qisqa va aniq javob ber."
)

INTENT_SYSTEM = (
    "Foydalanuvchi buyrug‘ini JSON ga aylantir. Faqat JSON qaytar, boshqa matn yozma. "
    'Format: {"intent": "...", "seconds": son yoki null, "text": matn yoki null}. '
    "intent qiymatlari: shorten (videoni qisqartirish), add_text (yozuv qo‘shish), "
    "add_music (musiqa), color (rang/yorug‘lik), make_video (yangi video yaratish), "
    "make_image (rasm yaratish), question (savol)."
)

FREE_TASKS = [
    ("qa", "Reels videoda birinchi 3 soniya nega muhim? 2-3 gapda javob ber."),
    ("ideas", "Qahvaxonam uchun 5 ta Reels g‘oyasini ber, har biri bitta qatorda."),
    ("script", "Restoran uchun 20 soniyali reklama ssenariysi: 4 ta sahna, har biriga ekrandagi qisqa matn."),
    ("hooks", "Kafel do‘koni uchun 3 ta qisqa hook matni yoz."),
    ("identity", "Salom! Sen kimsan va nima qila olasan?"),
    ("shots", "15 soniyalik kofe reklamasi uchun kadrlar ro‘yxati. Har qator: soniya | nima ko‘rinadi | ekrandagi matn"),
]

JSON_TASKS = [
    ("videoni 15 soniyaga qisqartir", {"intent": "shorten", "seconds": 15}),
    ("boshiga 'Chegirma 30%' degan yozuv qo‘sh", {"intent": "add_text"}),
    ("mahsulotim uchun oq fonda chiroyli rasm chiz", {"intent": "make_image"}),
    ("videoga quvnoq musiqa qo‘y", {"intent": "add_music"}),
    ("rangini iliqroq qil", {"intent": "color"}),
    ("tiktok uchun yarim daqiqalik reklama video yasab ber", {"intent": "make_video", "seconds": 30}),
    ("montajda o‘tish effekti nima degani?", {"intent": "question"}),
    ("oxirgi 5 soniyani olib tashla", {"intent": "shorten"}),
]


def _post(port: int, payload: dict) -> dict:
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)


def _wait(port: int, proc: subprocess.Popen, timeout: float = 180) -> None:
    t0 = time.time()
    while time.time() - t0 < timeout:
        if proc.poll() is not None:
            raise RuntimeError("llama-server exited")
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2) as r:
                if json.load(r).get("status") == "ok":
                    return
        except Exception:
            pass
        time.sleep(1)
    raise TimeoutError("model did not load")


def _ask(port: int, system: str, user: str, max_tokens: int) -> tuple[str, dict]:
    res = _post(
        port,
        {
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
            "temperature": 0.3,
            "max_tokens": max_tokens,
            "chat_template_kwargs": {"enable_thinking": False},
        },
    )
    text = res["choices"][0]["message"]["content"] or ""
    text = re.sub(r"<think>[\s\S]*?</think>", "", text).strip()
    return text, res.get("timings", {})


def _json_score(text: str, expected: dict) -> tuple[bool, dict | None]:
    m = re.search(r"\{[\s\S]*\}", text)
    if not m:
        return False, None
    try:
        obj = json.loads(m.group(0))
    except json.JSONDecodeError:
        return False, None
    ok = all(obj.get(k) == v for k, v in expected.items())
    return ok, obj


def bench(model: Path, port: int, threads: int, gpu_layers: int) -> dict:
    proc = subprocess.Popen(
        ["llama-server", "-m", str(model), "--port", str(port), "-c", "4096", "-t", str(threads),
         "-ngl", str(gpu_layers), "--jinja"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        t0 = time.time()
        _wait(port, proc)
        load_sec = time.time() - t0
        free, structured, gen_tps, prompt_tps = [], [], [], []
        for key, prompt in FREE_TASKS:
            text, tm = _ask(port, SYSTEM, prompt, 320)
            free.append({"task": key, "prompt": prompt, "answer": text})
            gen_tps.append(tm.get("predicted_per_second", 0))
            prompt_tps.append(tm.get("prompt_per_second", 0))
        for prompt, expected in JSON_TASKS:
            text, tm = _ask(port, INTENT_SYSTEM, prompt, 80)
            ok, obj = _json_score(text, expected)
            structured.append({"prompt": prompt, "expected": expected, "raw": text, "parsed": obj, "ok": ok})
            gen_tps.append(tm.get("predicted_per_second", 0))
        return {
            "model": model.name,
            "sizeMb": round(model.stat().st_size / 1e6),
            "loadSec": round(load_sec, 1),
            "genTokensPerSec": round(sum(gen_tps) / len(gen_tps), 1),
            "promptTokensPerSec": round(sum(prompt_tps) / len(prompt_tps), 1),
            "jsonAccuracy": sum(s["ok"] for s in structured) / len(structured),
            "free": free,
            "structured": structured,
        }
    finally:
        proc.terminate()
        proc.wait(timeout=30)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--models", nargs="+", type=Path, required=True)
    ap.add_argument("--threads", type=int, default=4, help="phone-like: 4 performance cores")
    ap.add_argument("--gpu-layers", type=int, default=0, help="0 = CPU only (closest to a phone baseline)")
    ap.add_argument("--out", type=Path, default=AI_ROOT / "data" / "llm" / "bench.json")
    args = ap.parse_args()
    results = []
    for i, m in enumerate(args.models):
        r = bench(m, 8811 + i, args.threads, args.gpu_layers)
        print(f"{r['model']}: {r['sizeMb']} MB, load {r['loadSec']} s, {r['genTokensPerSec']} tok/s, JSON {r['jsonAccuracy']:.0%}")
        results.append(r)
    args.out.write_text(json.dumps({"threads": args.threads, "gpuLayers": args.gpu_layers, "results": results}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
