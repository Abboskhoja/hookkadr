"""Model card (``card.md``) written next to every registered artifact."""

from __future__ import annotations

from pathlib import Path

from ..datasets import registry as datasets

LABELS_UZ = {
    "blurry": "xira (blur)",
    "dark": "qorong'i",
    "overexposed": "kuyib ketgan (ortiqcha yorug')",
    "noisy": "shovqinli",
    "low_contrast": "past kontrast",
}


def _f(x: float) -> str:
    return "—" if x != x else f"{x:.3f}"


def write_card(folder: Path, artifact: dict, report: dict, *, status: str) -> None:
    prov = artifact["provenance"]
    try:
        ds = datasets.get(prov["dataset"])
    except KeyError:
        ds = {}
    t, b = report["test"], report["baselineTest"]
    rows = "\n".join(
        f"| {LABELS_UZ.get(d, d)} | {_f(m['auc'])} | {_f(b['defects'][d]['auc'])} | {_f(m['ap'])} | "
        f"{_f(m['f1'])} | {_f(b['defects'][d]['f1'])} | {m['threshold']:.3f} | {m['positives']} |"
        for d, m in t["defects"].items()
    )
    src = ds.get("sources", {})
    text = f"""# {artifact['name']} {artifact['version']} — model kartasi

Holat: **{status}** · Arxitektura: {prov['architecture']} · {prov['framework']} · Bazaviy model: yo'q (noldan o'qitilgan)

## Nima qiladi
Video kadrini (FFmpeg analiz kadri, uzun tomoni {artifact['input']['analysisLongSide']} px) {len(artifact['input']['features'])} ta
o'lchanadigan belgi orqali baholaydi: sifat bali (0–1) va 5 ta nuqson ehtimoli —
{', '.join(LABELS_UZ[d] for d in artifact['outputs']['defects'])}.
HOOKKADR'da: sifat tekshiruvi namunalardagi texnik nuqsonlarni ko'rsatadi.
Model bahosi asosida lavhalarni avtomatik olib tashlash hali yoqilmagan.

## Nima qilmaydi
Kadrning mazmuni, estetikasi yoki "viral"ligini baholamaydi. Sifat bali — sintetik nuqsonlar
darajasidan o'rganilgan proksi, inson baholari bilan kalibrlanmagan.

## Ma'lumot
- Dataset: `{prov['dataset']}` (sha256 `{prov['datasetSha256'][:16]}…`), {src.get('count', '?')} ta foto,
  litsenziyalar: {src.get('licences', {})}; chiqarilgan mavzular: {src.get('excludedTopics', [])}.
- Manba: Wikimedia Commons "Quality images", faqat CC0 / public domain, cheklovsiz (manifestda har fayl
  muallifi, sahifasi va sha256 bilan).
- Belgilash: {prov['labelling']}.
- Split foto bo'yicha (bir foto faqat bitta split'da): {ds.get('counts', {})}.

## Test natijalari (model vs if/else qoida baseline'i)
Makro AUC: **{_f(t['macroAuc'])}** (qoida {_f(b['macroAuc'])}) · Makro F1: **{_f(t['macroF1'])}** (qoida {_f(b['macroF1'])}) ·
Sifat Spearman: **{_f(t['quality']['spearman'])}** (eng yaxshi bitta belgi `{b['quality']['rule']}`: {_f(b['quality']['spearman'])}) ·
Sifat MAE: {_f(t['quality']['mae'])}

| Nuqson | AUC | AUC (qoida) | AP | F1 | F1 (qoida) | Chegara | Musbat (test) |
|---|---|---|---|---|---|---|---|
{rows}

Chegaralar validatsiya split'ida F1 bo'yicha tanlangan; test faqat yakuniy baho uchun ishlatilgan.
Artefakt ↔ PyTorch farqi: {report['parityMaxAbsDiff']:.2e}. Eng yaxshi epoxa: {report['bestEpoch']}.

## Cheklovlar
- Sintetik nuqsonlar haqiqiy kamera xatolarini to'liq aks ettirmaydi (rolling shutter, fokus nafasi,
  siqish artefaktlari, HDR). Haqiqiy, inson tomonidan baholangan kadrlar bilan tekshirilmagan.
- Manba fotolar "Quality images" — ularning o'zida ham ataylab qilingan bokeh yoki tungi sahna bo'lishi mumkin.
- Tungi sahnalar o'qitishdan chiqarilgan: tungi videoni "qorong'i" deb belgilashi kutiladi.
- Shovqin analiz o'lchamida (kichraytirilgan kadr) qisman yo'qoladi.

## Qayta yaratish
```
uv run python -m hookkadr_ai.datasets.sources
{ds.get('rebuild', 'uv run python -m hookkadr_ai.datasets.build --config configs/scene_quality_v1.json')}
uv run python -m hookkadr_ai.training.train --config configs/scene_quality_v1.json
```
Run: `{prov['trainRun']}` · git `{prov['git']}`
"""
    (folder / "card.md").write_text(text)
