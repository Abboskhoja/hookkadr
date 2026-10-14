# scene_quality 1.0.0 — model kartasi

Holat: **production** · Arxitektura: MLP 15-32-32-6, ReLU · torch 2.14.1 · Bazaviy model: yo'q (noldan o'qitilgan)

## Nima qiladi
Video kadrini (FFmpeg analiz kadri, uzun tomoni 384 px) 15 ta
o'lchanadigan belgi orqali baholaydi: sifat bali (0–1) va 5 ta nuqson ehtimoli —
xira (blur), qorong'i, kuyib ketgan (ortiqcha yorug'), shovqinli, past kontrast.
HOOKKADR'da: sifat tekshiruvi namunalardagi texnik nuqsonlarni ko'rsatadi.
Model bahosi asosida lavhalarni avtomatik olib tashlash hali yoqilmagan.

## Nima qilmaydi
Kadrning mazmuni, estetikasi yoki "viral"ligini baholamaydi. Sifat bali — sintetik nuqsonlar
darajasidan o'rganilgan proksi, inson baholari bilan kalibrlanmagan.

## Ma'lumot
- Dataset: `scene_quality_synth_v1` (sha256 `45534512ebad3c25…`), 335 ta foto,
  litsenziyalar: {'cc0': 317, 'pd': 18}; chiqarilgan mavzular: ['night'].
- Manba: Wikimedia Commons "Quality images", faqat CC0 / public domain, cheklovsiz (manifestda har fayl
  muallifi, sahifasi va sha256 bilan).
- Belgilash: self-supervised: controlled defects with known severity on CC0/PD photos; not human-rated.
- Split foto bo'yicha (bir foto faqat bitta split'da): {'train': 2936, 'val': 576, 'test': 984}.

## Test natijalari (model vs if/else qoida baseline'i)
Makro AUC: **0.983** (qoida 0.943) · Makro F1: **0.862** (qoida 0.732) ·
Sifat Spearman: **0.823** (eng yaxshi bitta belgi `+tenengrad_log`: 0.449) ·
Sifat MAE: 0.131

| Nuqson | AUC | AUC (qoida) | AP | F1 | F1 (qoida) | Chegara | Musbat (test) |
|---|---|---|---|---|---|---|---|
| xira (blur) | 0.971 | 0.919 | 0.938 | 0.854 | 0.766 | 0.527 | 257 |
| qorong'i | 0.997 | 0.995 | 0.980 | 0.912 | 0.890 | 0.738 | 119 |
| kuyib ketgan (ortiqcha yorug') | 0.984 | 0.981 | 0.930 | 0.866 | 0.822 | 0.206 | 147 |
| shovqinli | 0.973 | 0.910 | 0.915 | 0.804 | 0.605 | 0.322 | 144 |
| past kontrast | 0.989 | 0.910 | 0.937 | 0.872 | 0.578 | 0.600 | 136 |

Chegaralar validatsiya split'ida F1 bo'yicha tanlangan; test faqat yakuniy baho uchun ishlatilgan.
Artefakt ↔ PyTorch farqi: 1.01e-06. Eng yaxshi epoxa: 29.

## Cheklovlar
- Sintetik nuqsonlar haqiqiy kamera xatolarini to'liq aks ettirmaydi (rolling shutter, fokus nafasi,
  siqish artefaktlari, HDR). Haqiqiy, inson tomonidan baholangan kadrlar bilan tekshirilmagan.
- Manba fotolar "Quality images" — ularning o'zida ham ataylab qilingan bokeh yoki tungi sahna bo'lishi mumkin.
- Tungi sahnalar o'qitishdan chiqarilgan: tungi videoni "qorong'i" deb belgilashi kutiladi.
- Shovqin analiz o'lchamida (kichraytirilgan kadr) qisman yo'qoladi.

## Qayta yaratish
```
uv run python -m hookkadr_ai.datasets.sources
uv run python -m hookkadr_ai.datasets.build --config configs/scene_quality_v1.json
uv run python -m hookkadr_ai.training.train --config configs/scene_quality_v1.json
```
Run: `scene_quality/20261014-030042` · git `9a2c139+dirty`
