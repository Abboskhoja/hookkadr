# HOOKKADR — AI Video Studio: to'liq loyiha hujjati

> Versiya: 1.0 · Sana: 2026-10-12 · Platformalar: iOS, Android (Flutter/Dart)
>
> Bu hujjat ikki o'quvchi uchun: (1) loyiha egasi va jamoa, (2) loyiha ustida
> ishlaydigan AI agentlar (Claude Code va boshqalar). Har bir bo'limda
> **HOZIR ISHLAYDI**, **QISMAN** yoki **REJADA** belgisi bor — hujjat
> haqiqiy holatni yashirmaydi.

---

## Mundarija

1. Mahsulot g'oyasi va chegaralari
2. Hozirgi holat (kod bazasi auditi)
3. Dizayn tizimi (ranglar, shrift, ikonka, spacing)
4. Ekranlar xaritasi va har bir ekran spetsifikatsiyasi
5. Pastki video sozlamalari paneli (Model · Ratio · Duration · Quality · Frames · More)
6. Chat va AI orkestratsiya
7. Multi-AI integratsiya: providerlar, API kalitlarini olish, imkoniyatlar jadvali
8. Video render va 4K
9. Offline rejim
10. Ma'lumotlar modeli (EditPlan va boshqalar)
11. Backend arxitekturasi (production)
12. Xavfsizlik, maxfiylik, xarajat va token hisobi
13. Flutter paketlari (tekshirilgan ro'yxat)
14. Sifat nazorati va testlar
15. Yo'l xaritasi (bosqichlar)
16. Ochiq savollar va risklar
17. AI agentlar uchun ish qoidalari

---

## 1. Mahsulot g'oyasi va chegaralari

**HOOKKADR** — chat orqali boshqariladigan mobil kreativ studiya. Foydalanuvchi
oddiy tilda yozadi, video/rasmlarini yuklaydi, har bir klipga izoh beradi;
tizim mos AI modellarni tanlab montaj rejasi tuzadi, kerak bo'lsa yangi kadr
yoki rasm yaratadi, natijani tahrirlanadigan loyiha sifatida beradi va
telefonda yoki serverda haqiqiy MP4 render qiladi.

Uchta tizim:

| Tizim | Vazifasi |
|---|---|
| AI Chat | Boshqaruv markazi: foydalanuvchi niyatini tushunadi |
| AI Creative Engine | Mos AI'ni tanlaydi: reja, tahlil, rasm/video generatsiya |
| Professional Editor | Aniq nazorat: timeline, kadr, subtitr, eksport |

Kimlar uchun: kontent yaratuvchilar, videograflar, montajchilar, dizaynerlar,
bizneslar va oddiy foydalanuvchilar. **Brend reklamasi** imkoniyatlardan biri
(Brand Kit orqali), lekin mahsulot faqat reklama uchun emas.

Asosiy qoidalar:

- Ishlamaydigan funksiya ishlayotgandek ko'rsatilmaydi.
- Pullik ishdan oldin xarajat va provider ko'rsatiladi, tasdiq olinadi.
- AI qaror qiladi, **deterministik engine bajaradi** (AI hech qachon videoni
  to'g'ridan-to'g'ri "kesmaydi" — u `EditPlan` yozadi, FFmpeg uni bajaradi).
- Original media hech qachon o'zgartirilmaydi (non-destructive).

---

## 2. Hozirgi holat (kod bazasi auditi)

| Qism | Holat | Fayl |
|---|---|---|
| Chat-first Home (Claude uslubida), suhbat tarixi, qidiruv | HOZIR ISHLAYDI | `lib/features/chat/chat_screen.dart` |
| Niyatni aniqlash: suhbat / reja / tahrir / rasm / AI video | HOZIR ISHLAYDI (deterministik qoidalar) | `lib/features/ai/intent.dart` |
| Provider adapterlari: Claude, OpenAI, Gemini | HOZIR ISHLAYDI (BYOK, kalit Keychain/Keystore'da) | `lib/features/ai/ai_clients.dart` |
| Auto router (Claude → OpenAI → Gemini → Offline) | HOZIR ISHLAYDI | `lib/app/app_controller.dart` |
| Gemini bilan videoni ko'rish (≤18 MB, inline) | HOZIR ISHLAYDI | `GeminiClient.analyzeVideo` |
| EditPlan v1, qat'iy validatsiya, AI javobini qayta so'rash | HOZIR ISHLAYDI | `lib/features/analysis/domain/edit_plan.dart`, `plan_generator.dart` |
| Ko'p klip + har biriga izoh, thumbnail, davomiylik, MB | HOZIR ISHLAYDI | `chat_screen.dart` (`_Clip`) |
| Muharrir: timeline, real klip preview, ±0.5 s, o'chirish, undo/redo | HOZIR ISHLAYDI | `lib/features/editor/editor_screen.dart` |
| **Offline MP4 render** (FFmpeg, LGPL build, 720p/1080p/4K) | HOZIR ISHLAYDI — simulyatorda integration test bilan tekshirilgan | `lib/features/render/*` |
| Galereyaga saqlash (video va rasm) | HOZIR ISHLAYDI | `export_sheet.dart`, `gal` |
| AI rasm (Gemini image / OpenAI gpt-image-1) | QISMAN — kod va mock testlar bor, haqiqiy kalit bilan sinalmagan | `generateImage` |
| AI video (Google Veo, long-running job) | QISMAN — kod va mock test bor; model ID haqiqiy kalit bilan tekshirilishi kerak | `GeminiClient.generateVideo` |
| AI o'zi generator uchun prompt yozadi | HOZIR ISHLAYDI | `PlanGenerator.writeGenerationPrompt` |
| Token hisoblagich (har javob + umumiy) | HOZIR ISHLAYDI (API qaytargan haqiqiy son) | `lib/features/ai/token_meter.dart` |
| Offline AI (Qwen3 0.6B, qurilmada) | QISMAN — integratsiya yozilgan, simulyatorda to'liq sinov davom etmoqda | `lib/features/ai/offline_model.dart` |
| Backend, auth, billing, push | REJADA | §11 |
| Storyboard / Frame Builder ekrani | REJADA | §4.7 |
| Brand Kit | REJADA | §4.10 |
| Multi-track (overlay, musiqa, voiceover) | REJADA | §4.8 |
| Lokalizatsiya uz/en/ru | REJADA (hozir faqat o'zbekcha) | — |

Arxitektura bo'yicha muhim farq: spetsifikatsiya **backend-first** (API kalitlari
faqat serverda). Hozirgi ilova **local-first + BYOK** (foydalanuvchi o'z
kalitini qurilmaning xavfsiz xotirasiga kiritadi). Bu dasturlash va "power
user"lar uchun to'g'ri, lekin do'konga chiqarishdan oldin §11 dagi backend
qo'shiladi va kalitsiz foydalanuvchilar uchun "HOOKKADR Credits" yo'li ochiladi.
Adapterlar interfeys orqali yozilgani uchun ularni backend proxy'ga ko'chirish
UI'ni o'zgartirmaydi.

---

## 3. Dizayn tizimi

### 3.1 Ranglar (tokenlar `lib/core/theme/app_theme.dart` da — manba haqiqati shu fayl)

Qaror (2026-10-12): palitra **yangi clapperboard logosiga** moslangan —
ko'k yorug'lik, iliq to'q sariq (amber) va to'q moviy. Mavzu: oq (light) va
qora (dark). Quyidagi qiymatlar kodga mos; o'zgarsa, kod yangi haqiqat.

**Brend**

| Token | HEX | Ishlatilishi |
|---|---|---|
| brand | `#FFAA58` | Dark rejimda aksent |
| brandPressed | `#A64B12` | Light rejimda aksent, bosilgan holat |
| peach / coral | `#FFD4A0` / `#FF9950` | Gradient |
| blue / blueLight | `#1673B8` / `#6BC9FF` | Logo yorug'ligi, gradient |
| success / warning / error | `#78B99A` / `#E4B76B` / `#E1847D` | Holatlar |

**Dark**

| Token | HEX |
|---|---|
| background | `#000000` |
| surface / surfaceRaised | `#111B27` / `#1C2B3C` |
| separator | `#35485E` |
| textPrimary / textSecondary / muted | `#F6F8FC` / `#B4C4D6` / `#95A8BC` |
| accent / onAccent | `#FFAA58` / `#111B27` |
| selected | `#38271C` |

**Light**

| Token | HEX |
|---|---|
| background | `#FFFFFF` |
| surface / surfaceRaised | `#F3F7FC` / `#E6EEF7` |
| separator | `#CEDAE8` |
| textPrimary / textSecondary / muted | `#152538` / `#50647B` / `#536A82` |
| accent / onAccent | `#A64B12` / `#FFFFFF` |
| selected | `#FFEAD6` |

**Kontrast (hisoblangan, WCAG AA ≥ 4.5:1):** dark onAccent/accent 9.2:1,
asosiy matn 19.8:1, ikkinchi matn 11.8:1; light onAccent/accent 5.8:1,
asosiy matn 15.5:1, ikkinchi matn 6.1:1, muted 5.2:1.

Eslatma: avvalgi spetsifikatsiyadagi terrakota palitra (`#D77854`) bekor
qilindi — logo ko'k va amber rangda.

### 3.2 Tipografiya

Inter (`google_fonts`), render uchun Inter TTF ilova ichida (`assets/fonts`).

| Daraja | O'lcham | Og'irlik |
|---|---|---|
| Display | 30–34 | SemiBold |
| Page title | 24 | SemiBold |
| Section title | 18–20 | SemiBold |
| Body | 15–16 | Regular |
| Secondary | 13–14 | Regular |
| Caption | 11–12 | Regular |
| Button | 14–16 | SemiBold |

### 3.3 Spacing va radius

8-point tizim. Ekran chetlari 16–20, kartalar radiusi 16–20, bottom sheet 24,
asosiy tugma 14–16, input 16–20 (composer 28), touch target ≥ 44×44.

### 3.4 Ikonkalar

Kutubxona: `lucide_icons_flutter` (ISC litsenziyali Lucide). Barchasi bir xil
chiziq qalinligida.

| Holat | Rang |
|---|---|
| Default | textSecondary |
| Active | accent |
| Selected fon | selected |
| Disabled | muted |
| Success / Error | `#78B99A` / `#E1847D` |
| Aksent tugma ustida | onAccent |

| Funksiya | Lucide nomi |
|---|---|
| Home | `house` |
| AI Chat | `messageCircle` |
| Video yaratish | `clapperboard` |
| Rasm | `image` |
| Yuklash | `upload` / `imageUp` |
| Kamera | `camera` |
| Format | `ratio` |
| Timeline | `panelsTopLeft` |
| Kadrlar | `film` |
| AI modellar | `brainCircuit` |
| Sozlamalar | `settings2` |
| Eksport | `download` |
| Render | `loaderCircle` |
| Ovoz | `audioLines` |
| Subtitr | `captions` |
| Qayta yaratish | `refreshCw` |
| Undo / Redo | `undo2` / `redo2` |
| O'chirish | `trash2` |

### 3.5 Harakat (animatsiya)

`flutter_animate`: xabarlar 300 ms fade + 6% slide; ro'yxatlar 25–90 ms
stagger; "ishlamoqda" holatida logo pulsatsiyasi va shimmer. Animatsiya hech
qachon ma'lumotni kechiktirmaydi (≤ 600 ms).

---

## 4. Ekranlar xaritasi

```
Splash → (birinchi marta) Onboarding: "Qaysi AI bilan ishlaymiz?"
       → Home / Create (chat)
            ├─ Chap panel: suhbatlar tarixi, qidiruv, Loyihalar, AI ulanishlari
            ├─ + menyu: Galereya, Kamera, Video sozlamalari
            ├─ Pill'lar: Ratio · Duration · Quality (+ Model)
            ├─ Xabar kartasi → Editor
            └─ Rasm → To'liq ekran → Galereyaga saqlash
       → Editor → Export sheet → Galereya
       → AI ulanishlari (Offline AI, Claude, OpenAI, Gemini)
       → Loyihalar (poster to'r)
```

### 4.1 Home / Create (chat) — HOZIR ISHLAYDI
- Bo'sh holat: markazda logo (sekin pulsatsiya), "Xayrli kech, bugun nima
  yaratamiz?", 3 ta tez taklif, "Davom eting" posterlari.
- Composer: klip kartalari (thumbnail, `clip_01`, davomiylik, MB, izoh),
  matn maydoni, `+`, format/davomiylik/sifat pill'lari, model tanlash, yuborish.
- Xabarlar: foydalanuvchi — o'ngda bubble; AI — fonsiz matn, ostida token
  soni va nusxalash; Activity bloki (haqiqiy bosqichlar); loyiha kartasi;
  rasm; "AI yozgan prompt" ochiladigan bo'lim.
- Holatlar: AI ulanmagan → "AI ulanishlari" tugmasi; 18 MB'dan katta klip →
  qizil ramka, yuborilmaydi; xato → qizil matn; davom etayotgan ish → spinner.

### 4.2 Editor — HOZIR ISHLAYDI (asosiy), REJADA (multi-track)
- Preview: kadr klipga bog'langan bo'lsa **haqiqiy video** (playhead bilan
  sinxron), aks holda rangli storyboard karta.
- Transport: undo/redo, timecode, play/pause.
- Timeline: o'lchagich, video/subtitr/audio qatorlari, playhead.
- Inspector: kadr davomiyligi ±0.5 s (ripple), o'chirish.
- Pastda: Materiallar, AI Edit (chat orqali tahrir).
- REJADA: split, speed, crop/rotate, overlay, musiqa qatori, rang, keyframe.

### 4.3 Export sheet — HOZIR ISHLAYDI
720p / 1080p / 4K tanlash → haqiqiy progress (FFmpeg statistikasi) →
bekor qilish → natija videosi → "Galereyaga saqlash". Materiali yo'q kadrlar
oldindan ogohlantiriladi va matnli karta bo'lib chiqadi.

### 4.4 AI ulanishlari — HOZIR ISHLAYDI
Har provider: rol, holat, maskalangan kalit, model nomi, Ulash/Uzish.
Offline AI: yuklab olish (progress), o'chirish. Maxfiylik va obuna haqida
ochiq izoh.

### 4.5 Loyihalar — HOZIR ISHLAYDI
Poster to'ri (kadr-shtrix), uzoq bosib o'chirish.

### 4.6 Onboarding — HOZIR ISHLAYDI
Bitta varaq: providerlar ro'yxati + "Keyinroq ulayman".

### 4.7 Storyboard / Frame Builder — REJADA
Sahna kartalari: raqam, thumbnail, rasm/video yuklash, "kadr yaratish",
prompt, kamera harakati, davomiylik, o'tish, audio izoh, reference,
qayta yaratish, nusxa, o'chirish, drag-and-drop. Ma'lumot modeli allaqachon
bor (`Shot` + `MediaSlot`), ekran qo'shiladi.

### 4.8 Multi-track Editor — REJADA
Qatorlar: Main video, Overlay, Images, Text, Subtitles, Voiceover, Music, SFX.
`EditPlan` v2 (§10.2) ga bog'liq.

### 4.9 Asset Library, Notifications, Billing, Usage, Profile — REJADA
Backend (§11) bilan birga.

### 4.10 Brand Kit — REJADA
Brend nomi, logo, ranglar, shrift, mahsulot rasmlari, reference video,
"brend ovozi", saqlangan promptlar. Generatsiya promptiga avtomatik qo'shiladi;
logo/matn AI natijasida noaniq chiqsa, render bosqichida overlay sifatida
qo'yiladi (AI'ga logo chizdirilmaydi).

---

## 5. Pastki video sozlamalari paneli

Hozir composer ichida: **Ratio · Duration · Quality** pill'lari va **Model**
tanlagichi (HOZIR ISHLAYDI). Spetsifikatsiyadagi to'liq panel:

| Sozlama | Variantlar | Izoh |
|---|---|---|
| Model | Auto, Claude, OpenAI, Gemini, Offline | Ulanmaganlar "ulanmagan" deb o'chirilgan |
| Ratio | 9:16, 16:9, 1:1, 4:5 (hozir); 3:4, 21:9, 2:3 (rejada) | Kichik geometrik preview bilan (rejada) |
| Duration | 15/30/45/60 s (montaj); generatsiya uchun 4–8 s (model cheklovi) | Uzun video = bir nechta sahna + montaj |
| Quality | 720p, 1080p, 4K | §8: native 4K vs upscale/eksport farqi ko'rsatiladi |
| FPS | 30 (hozir); 24/25/60 (rejada) | Eksport FPS ≠ AI native FPS |
| Frames | Storyboard'ga o'tish (rejada) | |
| More | Kamera harakati, uslub, yorug'lik, rang, seed, negative prompt, reference | Faqat provider qo'llaganlari ko'rinadi |

Qoida: model qo'llamaydigan qiymat tanlansa, eng yaqin mos variant taklif
qilinadi (masalan Veo 1:1 ni qo'llamasa → 9:16 + render paytida crop).

---

## 6. Chat va AI orkestratsiya

### 6.1 Niyat (intent) — `lib/features/ai/intent.dart`
Deterministik qoidalar (offline modelda ham bir xil ishlaydi):

| Niyat | Shart (soddalashtirilgan) |
|---|---|
| createPlan | Klip biriktirilgan, yoki "montaj/reklama/reels/kadr/video…" so'zlari |
| editPlan | Faol loyiha bor va savol emas ("3-kadrni qisqartir", "tezroq qil") |
| image | "rasm/surat/image/poster…" + "yarat/chiz/make/draw…" |
| video | "generatsiya/generate/veo/AI video" + "video/kadr/klip" |
| chat | Savol ("?" yoki savol so'zi), salomlashish, qolgan hammasi |

### 6.2 Pipeline (hozirgi)

```
Xabar → Intent
  chat      → Planner.converse(oxirgi 12 xabar) → javob (+token)
  image     → Planner prompt yozadi → Gemini/OpenAI rasm → fayl → chat
  video     → xarajat tasdig'i → Planner prompt yozadi → Veo job (poll) →
              MP4 → yangi loyiha (1 kadr) → Editor
  createPlan→ (klip bor) Gemini har klipni ko'radi → Planner EditPlan →
              validatsiya (+klip uzunligi tekshiruvi) → loyiha
  editPlan  → Planner to'liq yangi EditPlan (id'lar saqlanadi) → validatsiya
```

Planner = Auto router tanlagan model. Offline planner uchun EditPlan JSON
o'rniga oddiy "soniya | nima ko'rinadi | ekrandagi matn" ro'yxati so'raladi,
reja Dart'da deterministik quriladi (kichik model JSON'ni buzmasligi uchun).

### 6.3 Activity bloki
Faqat haqiqiy bosqichlar ko'rsatiladi; soxta foiz yo'q. Ilova yopilib
qolgan "ishlayotgan" bosqich qayta ochilganda "xato" sifatida tiklanadi.

### 6.4 Rejadagi yaxshilanishlar
- Streaming javob (Claude/OpenAI/Gemini SSE).
- EditPlan **patch** (to'liq qayta yozish o'rniga diff): `update/insert/delete`
  operatsiyalari — tasdiqlangan qarorlar o'zgarib ketmasligi uchun.
- Versiya tarixi (v1, v2…) va "oldingi versiyaga qaytish".
- Natijani sifat-tekshiruvchi AI (hook kuchi, subtitr o'qilishi).

---

## 7. Multi-AI integratsiya

### 7.1 Imkoniyatlar jadvali

| Provider | Matn/reja | Video ko'rish | Rasm | Video generatsiya | Ovoz | Holat |
|---|---|---|---|---|---|---|
| Anthropic Claude | ✅ | ❌ (faqat rasm/kadr) | ❌ | ❌ | ❌ | ULANGAN |
| OpenAI | ✅ | kadrlar orqali | ✅ (gpt-image-1) | rasmiy API'ni tekshirish kerak | TTS/STT | ULANGAN (matn, rasm) |
| Google Gemini | ✅ | ✅ native | ✅ (gemini-2.5-flash-image) | ✅ Veo (predictLongRunning) | — | ULANGAN (matn, video tahlil, rasm, Veo) |
| Offline (Qwen3 0.6B) | ✅ oddiy | ❌ | ❌ | ❌ | ❌ | ULANGAN (qurilmada) |
| Runway | — | — | — | ✅ | — | REJADA |
| Luma | — | — | ✅ | ✅ | — | REJADA |
| Kling | — | — | ✅ | ✅ | — | REJADA (rasmiy API va shartlar tekshirilsin) |
| fal.ai / Replicate | — | — | ✅ | ✅ | ✅ | REJADA (agregatorlar) |
| Stability AI | — | — | ✅ | — | — | REJADA |
| ElevenLabs | — | — | — | — | ✅ voiceover | REJADA |

Model identifikatorlari (`claude-sonnet-5-5`, `gpt-5`, `gemini-2.5-flash`,
`gemini-2.5-flash-image`, `gpt-image-1`, `veo-3.1-generate-preview`) bitta
joyda konstanta sifatida turibdi (`ai_clients.dart`). Ular provider
tomonidan o'zgaradi — **birinchi haqiqiy chaqiruvda tekshiring**.

### 7.2 API kalitlarini qanday olish (foydalanuvchi uchun qadamlar)

**Claude (Anthropic)**
1. `console.anthropic.com` da ro'yxatdan o'ting.
2. Billing → kredit qo'shing (API pullik, Claude Pro obunasidan alohida).
3. API Keys → "Create Key" → `sk-ant-...` ni nusxalang.
4. HOOKKADR → AI ulanishlari → Claude → kalitni qo'ying → "Tekshirish va ulash".

**OpenAI**
1. `platform.openai.com` → Billing → to'lov usuli/kredit.
2. API keys → "Create new secret key" (`sk-...`).
3. Rasm modeli uchun tashkilot tasdiqlanishi talab qilinishi mumkin.
4. HOOKKADR'da OpenAI'ni ulang.

**Gemini va Veo (Google)**
1. `aistudio.google.com` → "Get API key" (`AIza...`).
2. Veo va katta hajmlar uchun Google Cloud loyihasida billing yoqiladi
   (bepul tier'da Veo bo'lmasligi mumkin).
3. HOOKKADR'da Gemini'ni ulang. Video tahlili va Veo shu kalit bilan ishlaydi.

**Offline AI**
AI ulanishlari → Offline AI → "Yuklab olish" (~590 MB, bir marta, Wi-Fi tavsiya).
Kalit kerak emas.

**Rejadagi providerlar** (hujjat va narxni rasmiy saytidan tekshirish shart):
Runway (`runwayml.com` developer bo'limi), Luma (`lumalabs.ai` API),
fal.ai (`fal.ai`), Replicate (`replicate.com`), Stability (`platform.stability.ai`),
ElevenLabs (`elevenlabs.io`). Har biri uchun adapter `ai_clients.dart`
dagi naqsh bo'yicha yoziladi va mock testlar bilan qoplanadi.

### 7.3 Obunalar haqida (muhim)
Claude Pro, ChatGPT Plus/Pro, Google AI Pro kabi **iste'molchi obunalari API
huquqini bermaydi**. HOOKKADR hech qachon login/parol yoki sessiya cookie
so'ramaydi. Ulanish yo'llari: (1) foydalanuvchining API kaliti, (2) provider
rasmiy OAuth bersa — OAuth, (3) HOOKKADR Credits (backend orqali).

### 7.4 Auto router qoidalari
- Planner: tanlangan model (ulangan bo'lsa) → Claude → OpenAI → Gemini → Offline.
- Video ko'rish: faqat Gemini; yo'q bo'lsa va planner offline bo'lsa — faqat
  izoh va davomiylik bo'yicha "ko'r" reja (ochiq aytiladi).
- Rasm: Gemini → OpenAI.
- Video generatsiya: Veo (Gemini kaliti).
- Qimmat modelga **foydalanuvchi ruxsatisiz o'tilmaydi**.

---

## 8. Video render va 4K

### 8.1 Qurilmadagi render — HOZIR ISHLAYDI
- Paket: `ffmpeg_kit_flutter_new_full` (LGPL; GPL kodeklarsiz — ilova GPL
  bo'lib qolmasligi uchun). Kodlash: iOS `h264_videotoolbox`, Android
  `h264_mediacodec` (apparat).
- `buildRenderArgs` (sof funksiya, unit test bilan): har kadr uchun
  `trim → scale/crop → fps → tpad`, audio `atrim/apad` yoki jimlik,
  `concat`, subtitrlar `drawtext textfile=` (maxsus belgilar filtrni
  buzmaydi), `-movflags +faststart`.
- O'lchamlar: 9:16 → 1080×1920 / 720×1280 / **2160×3840 (4K)**;
  16:9 → 1920×1080 / **3840×2160**; 1:1; 4:5.
- Bitrate: 5 Mb/s (720p), 10 Mb/s (1080p), 35 Mb/s (4K).
- Tekshiruv: `integration_test/render_test.dart` — simulyatorda haqiqiy klip
  yaratiladi, 3 kadr + subtitr render qilinadi, ffprobe bilan 720×1280,
  6 s, audio bor ekani tasdiqlanadi.

### 8.2 4K qoidalari
- **Native 4K generatsiya**: faqat provider rasmiy qo'llaganda.
- **4K eksport/upscale**: past sifatli manbadan 4K konteynerga chiqarish —
  sifat manbadan yuqori bo'lmaydi; UI buni ochiq yozishi kerak (rejada:
  Export sheet'da "manba 1080p — 4K upscale" ogohlantirishi).
- 4K render telefonda sekin va issiqlik chiqaradi; production'da server render.

### 8.3 Server render — REJADA
FFmpeg workerlar navbat orqali, original assetlardan; progress webhook/SSE;
natija signed URL bilan.

---

## 9. Offline rejim

| Ish | Offline | Izoh |
|---|---|---|
| Suhbat | ✅ (Offline AI o'rnatilgan bo'lsa) | Qwen3 0.6B — oddiy, qisqa javoblar |
| Montaj rejasi | ✅ | Kadr ro'yxati → deterministik EditPlan |
| Kliplarni "ko'rish" | ❌ | Faqat izoh va davomiylik bo'yicha |
| Muharrir, preview, undo | ✅ | |
| MP4 render (720p–4K) | ✅ | FFmpeg qurilmada |
| Rasm / video generatsiya | ❌ | Telefonda amaliy emas; bulut kerak |
| Galereyaga saqlash | ✅ | |

Talablar: iOS 16+, Android minSdk 30 (LiteRT-LM), arm64. Katta modellar
(Gemma 4 E2B, ~2.4 GB) keyinchalik "Kuchliroq offline model" sifatida
qo'shilishi mumkin; iOS'da `increased-memory-limit` entitlement kerak bo'ladi.

---

## 10. Ma'lumotlar modeli

### 10.1 EditPlan v1 (amalda)
```json
{
  "schemaVersion": 1,
  "title": "…", "summary": "…",
  "durationSec": 30, "aspectRatio": "9:16",
  "shots": [{"id": "s1", "startSec": 0, "endSec": 2.5,
             "description": "…", "camera": "…", "transitionIn": "…",
             "mediaSlotId": "m1",
             "sourceClipId": "clip_02", "sourceIn": 4.0, "sourceOut": 6.5}],
  "mediaSlots": [{"id": "m1", "kind": "video", "description": "…",
                  "requiredDurationSec": 3}],
  "captions": [{"startSec": 0.5, "endSec": 2, "text": "…"}],
  "audioTracks": [{"kind": "music", "startSec": 0, "endSec": 30, "description": "…"}],
  "export": {"resolution": "1080p", "fps": 30}
}
```
Validatsiya: versiya, format, kadrlar ketma-ket va ustma-ust emas,
davomiylik ichida, slot havolalari mavjud, `sourceIn < sourceOut`,
`sourceOut ≤ klipning haqiqiy uzunligi`, subtitr/audio chegarada.

### 10.2 EditPlan v2 (rejada)
`tracks[]` (main/overlay/text/subtitle/voiceover/music/sfx), har klipda
`speed`, `crop`, `transform`, `volume`, `fade`, `filters`; `operations`
patch formati; `version` tarixi.

### 10.3 Lokal saqlash (amalda)
- Loyihalar: `projects_v1` (SharedPreferences), kliplar
  `Documents/clips/`, renderlar `Documents/renders/`, rasmlar `Documents/images/`.
- Suhbatlar: `chats_v1`.
- Kalitlar: `flutter_secure_storage` (Keychain/Keystore).
- Tokenlar: `tok_in_*`, `tok_out_*`.

### 10.4 Server jadvallari (rejada)
users, workspaces, projects, project_members, conversations, messages,
assets, asset_annotations, storyboards, scenes, timelines, timeline_tracks,
timeline_clips, ai_providers, ai_models, provider_connections,
generation_jobs, render_jobs, job_events, exports, usage_records,
billing_transactions, notifications, audit_logs. Har birida UUID PK,
`created_at/updated_at`, `owner_id`/`workspace_id`, `status`, soft delete
(`deleted_at`), kerakli indekslar, migratsiyalar.

---

## 11. Backend arxitekturasi (production) — REJADA

Tanlov: **NestJS (TypeScript)** — ilgari tanlangan yo'nalish, yagona tilda
typed API kontraktlari; media ishlari alohida FFmpeg workerlarda.

```
Flutter ──HTTPS──▶ API (NestJS) ──▶ PostgreSQL
                     │   ├─▶ Redis + BullMQ (jobs)
                     │   ├─▶ S3/R2 (signed, multipart upload)
                     │   └─▶ AI Router ─▶ Claude/OpenAI/Gemini/Veo/Runway/…
                     └─▶ SSE/WebSocket (job holati), Push (FCM/APNs)
Workers: media-ingest (proxy, thumbnail, waveform, transcript, scenes),
         render (FFmpeg), generation (provider job polling/webhooks)
```

Endpointlar: `/auth`, `/users/me`, `/projects[/{id}]`,
`/projects/{id}/messages|assets|timeline|storyboard`, `/uploads/init|complete`,
`/providers`, `/providers/connections`, `/models`, `/models/capabilities`,
`/generation/jobs[/{id}]`, `/editing/jobs`, `/exports`, `/billing/estimate`,
`/billing/usage`, `/notifications`, `/webhooks/{provider}`. Har biri uchun:
schema (zod), auth, validatsiya, xato kodlari, pagination, idempotency key,
rate limit, testlar.

Job holatlari: Draft → Validating → WaitingForApproval → Queued → Uploading →
Processing → Rendering → Completed | Failed | Cancelled. Progress faqat
haqiqiy statusdan.

---

## 12. Xavfsizlik, maxfiylik, xarajat va token hisobi

- API kalitlari kodda yo'q; qurilmada Keychain/Keystore, serverda shifrlangan vault.
- Kalit chat matnida, logda, analitikada ko'rinmaydi; UI'da maskalanadi.
- Videoni Gemini'ga yuborishdan oldin bir martalik rozilik so'raladi;
  Veo'dan oldin pullik xizmat haqida tasdiq so'raladi.
- Klip izohlari va tahlil matnlari AI uchun **ma'lumot**, ko'rsatma emas
  (prompt injection himoyasi system prompt'da yozilgan).
- **Token hisobi (amalda):** har provider javobidagi haqiqiy `usage`
  (Claude `input/output_tokens`, OpenAI `prompt/completion_tokens`, Gemini
  `usageMetadata`) yig'iladi; har AI xabarida `↑kirish ↓chiqish token`,
  umumiy son saqlanadi. Offline model token sarflamaydi.
- Rejada: narx jadvali (rasmiy narxlardan, konfiguratsiyada), taxminiy
  xarajat oynasi, byudjet limiti, HOOKKADR Credits, App Store/Google Play
  raqamli xarid qoidalari.

---

## 13. Flutter paketlari

| Paket | Versiya | Maqsad | Izoh |
|---|---|---|---|
| google_fonts | ^6.3.3 | Inter | 9.x Flutter 3.47 material bilan tip mos emas |
| flutter_animate | ^4.5 | Animatsiyalar | |
| lucide_icons_flutter | ^3.1 | Ikonkalar | ISC |
| image_picker | ^1.x | Galereya/kamera, ko'p video | |
| video_player | ^2.14 | Preview, davomiylik | |
| video_thumbnail | ^0.5 | Thumbnail | SPM qo'llamaydi (CocoaPods) |
| path_provider | | Fayl yo'llari | |
| flutter_secure_storage | ^11 | Kalitlar | |
| shared_preferences | ^2.5 | Loyiha/suhbat | Keyin SQLite/drift'ga |
| http | | API | Keyin dio (interceptor, retry) |
| ffmpeg_kit_flutter_new_full | ^2.5 | Offline render | LGPL; original ffmpeg-kit arxivlangan |
| gal | | Galereyaga saqlash | |
| flutter_edge_ai + _litertlm | ^2.2 / ^1.12 | Offline LLM | flutter_gemma o'rnini bosgan; iOS 16, minSdk 30 |
| cupertino_icons | | (eski joylar) | |

Rejada (moslik tekshirilib): flutter_riverpod, go_router, dio, freezed,
json_serializable, file_picker (audio/rasm), just_audio, cached_network_image,
permission_handler, connectivity_plus, intl (uz/en/ru), flutter_local_notifications,
sentry_flutter, in_app_purchase.

Holat boshqaruvi qarori: hozir `ChangeNotifier + InheritedNotifier` (kichik,
bog'liqliksiz). Ekranlar soni oshganda Riverpod'ga o'tish — `AppController`
bo'limlarga bo'linadi (providers, projects, chats, offline).

---

## 14. Sifat nazorati va testlar

Amalda (`flutter test` — 40 ta):
- EditPlan validatsiyasi (6), generator retry/xatolar (8), intent (4),
  offline reja quruvchi (4), rasm/Veo adapterlari (3), router (3), suhbat
  saqlanishi, PlanOps (3), render argumentlari (4), widget testlar (3).

Integration (simulyatorda):
- `integration_test/render_test.dart` — **o'tdi**.
- `integration_test/offline_llm_test.dart` — model yuklash + suhbat + reja.

Rejada: golden testlar (light/dark), accessibility (screen reader, text
scale 200%), katta fayllar, internet uzilishi, bekor qilish, Android qurilma
testi, backend e2e.

---

## 15. Yo'l xaritasi

| Bosqich | Natija | Holat |
|---|---|---|
| 1. Foundation | Dizayn tizimi, chat, loyihalar, lokal saqlash | ✅ asosan tayyor |
| 2. Media workflow | Ko'p klip, izoh, thumbnail, preview | ✅ (Asset Library, Storyboard ekrani qoldi) |
| 3. AI integrations | Adapterlar, router, video tahlil, rasm, Veo, offline | ✅/QISMAN (haqiqiy kalitlar bilan sinov) |
| 4. Editor | Timeline, undo/redo, real preview, offline render, 4K | ✅ asosiy; multi-track rejada |
| 5. Production | Backend, auth, billing, push, server render, lokalizatsiya, store | REJADA |

Keyingi aniq qadamlar (tartib bilan):
1. Haqiqiy kalitlar bilan Claude/OpenAI/Gemini/Veo/rasm chaqiruvlarini sinash, model ID'larni tasdiqlash.
2. Storyboard/Frame Builder ekrani.
3. EditPlan patch + versiya tarixi.
4. Lokalizatsiya (uz/en/ru).
5. Backend MVP (auth, uploads, jobs, AI proxy) va BYOK → server proxy.
6. Multi-track (musiqa, voiceover — ElevenLabs), Brand Kit.

---

## 16. Ochiq savollar va risklar

- Veo, gpt-image-1, gemini-2.5-flash-image model nomlari va narxlari o'zgarishi mumkin.
- Kichik offline model o'zbek tilida zaif; sifat uchun kattaroq model (2–4 GB) kerak.
- Telefonda 4K render sekin; uzun videolar uchun server render zarur.
- Do'kon siyosatlari: AI kontent moderatsiyasi va shikoyat tugmasi (Google Play talab qiladi).
- Mualliflik huquqi: musiqa litsenziyasi, ovoz klonlash, inson qiyofasi roziligi.
- Bir vaqtda bir nechta AI vosita repoda ishlasa, fayllar to'qnashadi —
  bitta "egasi" bo'lishi kerak.

---

## 17. AI agentlar uchun ish qoidalari

1. Ishlamaydigan narsani ishlayotgandek ko'rsatma; mock faqat testlarda.
2. API kalitini kodga yozma; kalitlar faqat secure storage yoki serverda.
3. Yangi provider = `TextModel`/generator adapter + mock test + ulanishlar ekranida qator.
4. AI faqat `EditPlan` yozadi; render `buildRenderArgs` orqali. Shell buyrug'ini AI'ga berma.
5. Har o'zgarishdan keyin: `flutter analyze` (0 muammo), `flutter test` (hammasi o'tadi),
   iloji bo'lsa `flutter build ios --simulator`.
6. Ranglar faqat `AppPalette` tokenlaridan; ikonkalar faqat Lucide'dan.
7. Foydalanuvchiga matnlar o'zbekcha (lotin), aniq va qisqa.
8. Pullik ish (Veo, rasm) oldidan tasdiq; qimmat modelga o'zboshimcha o'tma.

---

## 18. O'zgarishlar jurnali

### 2026-10-12 — Joriy video / Keyingi amal, versiyalar, hajm hisoblagichi
- **Workspace** (chat tepasi, loyiha bor bo'lsa): haqiqiy MP4 preview (contain, qora sahna,
  ijro/seek/vaqt), **joriy video** qatori faqat haqiqiy render ma'lumotidan
  (`9:16 · 1080p · 15 s · 30 FPS · MP4 · 19 MB`); render yo'q bo'lsa "render qilinmagan",
  hech narsa o'ylab topilmaydi. Reja renderdan keyin o'zgarsa "Reja o'zgardi — qayta eksport".
  Klaviatura ochilganda mini-qatorga qisqaradi. Tugmalar: Tahrirlash, Versiya (undo), Eksport.
- **Keyingi amal paneli** (composer ustida): "Keyingi:" format · davomiylik · sifat + taxminiy hajm.
- **FileSizeEstimator** (`lib/features/render/export_presets.dart`): presetlar 360p/720p/1080p/4K,
  formula `(video_bps + audio_bps) × s / 8`, o'nlik MB, UI'da doim "taxminiy". Renderer ham
  shu presetlardan bitrate oladi.
- **Versiyalar**: har reja o'zgarishi oldingisini `history` ga saqlaydi (20 tagacha), `undoPlan`.
- **EditDiffCard**: AI tahriridan keyin "N ta o'zgarish qo'llandi" ro'yxati va Undo.
- **Semantik tokenlar** (`HookkadrSemanticColors`): actionPrimary/Secondary, borderSubtle,
  borderStrong (`#7A90A8` / `#607890`), focusRing, videoStage/Chrome, scrim. Kontrast testlari bor.
- **AppMotion**: 180/200/150/280/220 ms tokenlar; tizim "animatsiyani kamaytirish" yoqilsa
  faqat 100 ms fade, logo pulsatsiyasi to'xtaydi.
- **Logo**: yagona `BrandLogo` vidjeti (`assets/images/launcher_icon.png`).

Hali qilinmagan (shu spetsifikatsiyadan): 4 tabli navigatsiya (Chat · Studio · Projects ·
Profile), Storyboard ekrani, Compare, ModelCapabilityRegistry, mikrofon, streaming javob,
tablet ikki ustunli layout, Riverpod/go_router migratsiyasi, backend.

### 2026-10-12 — Tez montaj: video darhol tayyor
- **MediaAnalyzer** (`lib/features/render/media_analyzer.dart`, offline FFmpeg): har klipga bitta
  past-o'lchamli o'tish — sahna almashishlari (`select=gt(scene,0.32)` + `showinfo`) va jim
  pauzalar (`silencedetect -35dB, 0.45 s`). Natija `ClipFacts`, AI uchun `hint` matni.
- **AutoEditor** (`lib/features/plan/auto_editor.dart`): AI'siz deterministik montaj —
  pauzalarni kesadi, sahna chegaralarida bo'ladi, eng dinamik klipdan 2 s hook, keyin
  foydalanuvchi tartibida ~2.5 s ritm. Materialni takrorlamaydi; yetmasa video qisqaroq bo'ladi.
- **Oqim**: klip tashlash → o'lchash → (Gemini bo'lsa AI reja + o'lchangan faktlar, aks holda
  AutoEditor) → **avto-render** (haqiqiy % progress) → chat tepasida video o'ynaydi.
  AI ulanmagan bo'lsa ham ishlaydi. Chatdagi tahrirdan keyin ham avto-render.
- Sozlamalarda "Avto-render" o'chirgichi. 18 MB'dan katta kliplar Gemini'ga yuborilmaydi —
  ular AutoEditor bilan offline montaj qilinadi.
- Integration test: 3 sahnali, pauzali klip yasaladi → tahlil → avto-montaj → 720×1280 MP4.

### 2026-10-12 — Arxitektura: birinchi refaktor qadami va CI
- **Agent**: `.claude/agents/flutter-senior-architect.md` (Clean Architecture, SOLID, Riverpod/BLoC,
  testlar, CI). Xotirasi: `~/.claude/agent-memory/flutter-senior-architect/`.
- **MontageService** (`lib/features/montage/application/montage_service.dart`): "klip → o'lchash →
  reja → tekshiruv → saqlash → render → joriy natija" oqimi widget'dan application qatlamiga
  chiqarildi. Portlar: `ClipAnalyzer` (MediaAnalyzer), `VideoRenderer` (RenderService),
  `ProjectRepository` (AppController). Chat endi faqat bosqich va progressni ko'rsatadi.
  Fake adapterlar bilan 6 ta unit test (`test/montage_service_test.dart`).
- **CI**: `.github/workflows/flutter_ci.yml` — format (`--set-exit-if-changed`), analyze, test;
  keyin Android debug APK va iOS simulator build. Kod `dart format` qilingan.
  Eslatma: loyiha hali git repozitoriy emas — CI ishlashi uchun GitHub'ga push qilish kerak.

**Keyingi refaktor bosqichlari (tartib bilan):**
1. Chat orkestratsiyasini (`_send`: intent → chat/rasm/video/reja) `ChatOrchestrator`
   application service'ga chiqarish; widget faqat holatni ko'rsatadi.
2. Riverpod'ni kiritish: `AppController` ni bo'laklarga ajratish — `providersProvider`
   (ulanishlar), `projectsRepositoryProvider`, `chatsRepositoryProvider`, `offlineModelProvider`;
   ekranlar `ref.watch(...select(...))` bilan faqat kerakli bo'lakni tinglaydi (ortiqcha rebuild yo'q).
3. Data qatlami: SharedPreferences o'rniga SQLite (drift) — loyihalar, versiyalar, suhbatlar;
   repository interfeyslari o'zgarmaydi.
4. go_router: Chat · Studio · Projects · Profile tablari, deep link `/project/:id`.
5. Og'ir ishlar: o'lchash va render allaqachon native FFmpeg'da (UI isolate'ni bloklamaydi);
   katta JSON parse/diff uchun `Isolate.run` faqat profil ko'rsatsa.

### 2026-10-12 — HOOKKADR serveri (Cursor usuli), login, montaj sahifasi
- **Qaror**: foydalanuvchi HOOKKADR'ga kiradi (Google/Apple, Firebase Auth), AI kalitlari faqat
  serverda, to'lov HOOKKADR kreditlari bilan (1 kredit = $0.01, haqiqiy token sarfi bo'yicha).
- **Server** (`server/`, Node 26 + TypeScript + Fastify, SQLite kredit jurnali): `/v1/me`,
  `/v1/usage`, `/v1/complete` (Claude), `/v1/video/analyze` (Gemini), `/v1/images` (Gemini).
  402 da provayder chaqirilmaydi, provayder xatosida pul yechilmaydi, per-user rate limit.
  12 ta server testi + ilova↔server uchma-uch test (lokal, dev rejim) o'tdi. CI'da server job.
- **Ilova**: `HookkadrCloudClient` (TextModel + VideoAnalyst + ImageGenerator), Auto router uni
  birinchi tanlaydi; sarlavhada kredit; ulanishlarda "HOOKKADR hisobi" kartasi.
- **Hali yo'q**: Google/Apple kirish (Firebase loyihasi kerak — `server/README.md` checklist),
  serverni deploy qilish, App Store/Play orqali kredit sotib olish (`/v1/billing/verify`).
- **OpenRouter login** (bitta OAuth bilan Claude/GPT/Gemini) zaxira yo'l sifatida qoldi.
- **Montaj sahifasi** (qaychi ikonkasi): kliplar → format/soniya/sifat → "Montaj qilish" → MP4.
- Splash'dagi logo olib tashlandi (iOS va Android 12+).

### 2026-10-12 — Pro Studio poydevori: Studio asboblari, musiqa, ritmga kesish
- **Engine qarori**: o'z FFmpeg engine'imiz davom etadi (ishlaydi, testlangan, litsenziya to'lovsiz).
  IMG.LY/Banuba keyinroq 30+ daqiqalik loyihalar uchun proof-of-concept'da baholanadi.
- **Studio amallari** (`PlanOps`, hammasi Undo/Redo bilan): playhead'da kesish (split), nusxa,
  chapga/o'ngga ko'chirish, boshidan trim (manba ichida), davomiylik, ripple delete,
  matn qo'shish/tahrirlash/o'chirish (timeline'dagi matn bosiladi).
- **Musiqa qatlami** (`EditPlan.music`): foydalanuvchi audio fayli, ovoz balandligi, boshlanish
  nuqtasi, oxirida so'nish; renderda sikl, **gap paytida avtomatik pasayish** (sidechain ducking).
- **BeatDetector** (offline): energiya onsetlari → autokorrelyatsiya (120 BPM atrofida prior,
  yarim-davr tekshiruvi) → kasr davr + ±1 kadr oynada faza. 90/120/150 BPM testlarda to'g'ri;
  simulyatorda haqiqiy audio: 120.2 BPM.
- **Ritmga moslash**: har bir kesim va oxiri eng yaqin zarbaga (±0.6 s) ko'chadi, kadr ≥0.5 s.
- Testlar: 80+ unit/widget, 4 ta simulyator integration (montaj, rasm→video, avto-montaj, musiqa).

### 2026-10-12 — O'tishlar, tezlik va harakat
- **Shot maydonlari** (sxema): `transition` (cut, crossfade, fadeBlack, slide, zoom),
  `transitionSec` (0.1–2), `speed` (0.25–4), `motion` (none, punchIn, slowZoom). AI ham ularni yozadi.
- **Render**: o'tishlar `xfade` bilan; chiquvchi kadr manbadan o'tish uzunligicha uzaytiriladi,
  shuning uchun video uzunligi, subtitr va musiqa zarbalari siljimaydi (simulyatorda 7.5 s → 7.5 s).
  Tezlik: video `setpts`, audio `atempo` zanjiri (0.5–2 dan tashqarida ham). Harakat: 20%
  oversample + `zoompan`. Birinchi kadrda "qoradan chiqish" = fade-in.
- **Muharrir**: kadr tanlansa ✨ Effekt paneli (o'tish, "hamma kadrlarga", tezlik, harakat);
  timeline'da tezlik (2×) va o'tish belgisi. Har amal undo bilan.
- Widget test kichik telefonda transport qatori sig'masligini topdi — tuzatildi.
- Cheklov: effektlar muharrir preview'ida emas, eksport qilingan videoda ko'rinadi.

### 2026-10-12 — Timeline: media qo'shish, pinch-zoom, waveform, freeze frame
- **Media qo'shish** muharrirda (`+`): video yoki rasm → loyihaga nusxalanadi, timeline oxiriga
  qo'shiladi (klip id'lari to'qnashmaydi), bitta undo bilan.
- **Pinch-to-zoom**: ikki barmoq bilan timeline 16–240 px/s; xom pointer hodisalari orqali,
  shuning uchun gorizontal scroll bilan to'qnashmaydi.
- **Waveform**: musiqa qo'shilganda bir marta hisoblanadi (0.1 s oynalar, vaqt bo'yicha —
  test yaxlitlash siljishini topdi va tuzatildi), `music.peaks` da keshlanadi, CustomPaint.
- **Freeze frame** (❄): playhead'dagi kadr 1 s ushlab turiladi (`shot.freeze`), ovozsiz;
  preview'da ham to'xtab turadi.
- Android build tuzatildi: `video_thumbnail` (jcenter, Gradle 9 da yiqilardi) olib tashlandi,
  thumbnail'lar FFmpeg bilan.
- Testlar: 98 unit/widget, 7 simulyator integration. iOS va Android debug build'lari yig'iladi.
