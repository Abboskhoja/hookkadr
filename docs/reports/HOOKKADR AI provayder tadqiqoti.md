# Eskirgan modellar HOOKKADR'ni to'qqiz kunda sindiradi

HOOKKADR'ning OpenAI rasm yo'li **2026-yil 23-oktabrda** ishlamay qoladi. `lib/features/ai/ai_clients.dart:307` dagi `gpt-image-1` shu kuni o'chiriladi, OpenAI esa uning o'rniga `gpt-image-2.5-flare` (tezkor) va `gpt-image-2.5-sunburst` (aniq tahrir) modellarini ko'rsatadi ([OpenAI Deprecations](https://developers.openai.com/api/docs/deprecations)). Google tomonda `gemini-2.5-flash-image` eskirgan, Imagen esa Gemini API'da butunlay yopilgan. `veo-3.1-generate-preview` hali ishlaydi, lekin Preview maqomida qolmoqda. OpenAI'ning Sora 2 API'si 24-sentabrda yopilgan va uning o'rnini bosadigan API yo'q. Render tomonda joriy tanlov to'g'ri: LGPL `ffmpeg_kit_flutter_new_full` 2.5.7 (FFmpeg 8.1.2). Asl arthenica loyihasi 2-iyul 2026 da arxivlangan, HOOKKADR ishlatadigan filtrlarning birortasi esa GPL ro'yxatida yo'q. O'zbekcha subtitr uchun so'z darajasida timestamp beradigan hujjatlashtirilgan hosted yo'l faqat ikkita: ElevenLabs Scribe v2 va Azure `uz-UZ` fast transcription. OpenAI, Deepgram va AssemblyAI o'zbekchani amalda qo'llab-quvvatlamaydi. Ovoz uchun ElevenLabs Eleven v3/v4 va Azure'ning ikkita `uz-UZ` ovozi, musiqa uchun esa Eleven Music tijoriy jihatdan eng aniq variant. Huquqiy talablar quyidagicha:

- Apple 5.1.2(i) har qanday third-party AI'ga shaxsiy ma'lumot yuborishdan oldin aniq ruxsat olishni talab qiladi.
- Google Play AI natijalari uchun ilovadan chiqmasdan ishlaydigan shikoyat tugmasini talab qiladi.
- EU AI Act 50-moddasi 2-avgust 2026 dan amalda.
- O'zbekistonda mart 2026 tuzatishidan keyin faqat biometrik, genetik va telekom ma'lumotlari mahalliy saqlanishi shart.

Master prompt uchun eng muhim xulosa: model ID'lari Dart konstantasi emas, server konfiguratsiyasi bo'lishi kerak, chunki OpenAI rasm modeli 2026-yilning o'zida ikki marta almashdi (`gpt-image-2` aprelda, `gpt-image-2.5-*` sentabrda) ([Wikipedia: GPT Image](https://en.wikipedia.org/wiki/GPT_Image)).

## Shoshilinch harakatlar: 13-dekabr 2026 gacha bo'lgan muddatlar

| Muddat | Nima sodir bo'ladi | HOOKKADR'dagi joy | Harakat |
|---|---|---|---|
| **23-okt 2026** (9 kun qoldi) | `gpt-image-1` API'dan o'chiriladi | `ai_clients.dart:307`, `capability_registry.dart:80`, `HOOKKADR_BLUEPRINT.md` 7.1-bo'lim | `gpt-image-2.5-flare` ga almashtirish, o'lcham jadvalini yangilash, haqiqiy kalit bilan smoke test |
| **17-noy 2026** yoki keyinroq | Vertex `veo-3.1-generate-001` va `-fast-generate-001` uchun eng erta retirement sanasi | hozir ishlatilmaydi | Vertex'ga ko'chishni bu ID'larga bog'lamang |
| **1-dek 2026** | `gpt-image-1-mini`, `gpt-image-1.5`, `chatgpt-image-latest` API'dan olib tashlanadi | kodda yo'q | Ularni "arzon zaxira" sifatida tanlamang |
| **2-dek 2026** | EU AI Act 50(2): machine-readable belgilash. Kechiktirilgan muddat faqat 2-avgustdan oldin bozorda bo'lgan tizimlarga tegishli (ikkilamchi manba) | eksport (`render_service.dart`) | Server tomonda C2PA imzosi. Yangi EU relizi bo'lsa, birinchi kundanoq majburiy |

Muddati o'tgan, lekin repo hujjatlarida hali aks etmagan to'rtta fakt bor:

- **Sora 2 va Videos API 24-sentabr 2026 da yopilgan** ([OpenAI video generation guide](https://developers.openai.com/api/docs/guides/video-generation)). Blueprint'dagi "OpenAI — video: rasmiy API'ni tekshirish kerak" qatori endi "mavjud emas" deb yozilishi kerak.
- Gemini API'dagi barcha `imagen-4.0-*` modellari **17-avgust 2026 da o'chirilgan** ([Gemini API Deprecations](https://ai.google.dev/gemini-api/docs/deprecations)).
- Apple'ning yangi yosh reytingi so'rovnomasiga javob berish muddati **31-yanvar 2026** edi. Javob berilmagan bo'lsa, App Store Connect yangilanishlarni bloklaydi ([9to5Mac](https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/)).
- `gemini-2.5-flash-image` bo'yicha Google manbalari bir-biriga zid. Pricing sahifasi o'chirish sanasini 2-oktabr 2026 deb ko'rsatadi. Deprecations sahifasi va Agent Platform release note'i esa uni **15-mart 2027** ga ko'chirilgan deydi ([Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing); [Agent Platform release notes](https://docs.cloud.google.com/gemini-enterprise-agent-platform/release-notes)). Ikkinchisi yangiroq, shuning uchun BYOK yo'li hozircha ishlashi kerak. Baribir uni haqiqiy kalit bilan hoziroq tekshirib ko'rish arzon sug'urta.

## Rasm generatsiyasi: `gpt-image-2.5-*` va `gemini-nano-banana-2.1` yangi asos

**OpenAI.** OpenAI'ning models sahifasida endi faqat ikkita rasm modeli qolgan:

- **`gpt-image-2.5-sunburst`**: "most capable model for image generation and editing"; snapshot `gpt-image-2.5-sunburst-2026-09-08`.
- **`gpt-image-2.5-flare`**: "fast, high-quality everyday image generation"; snapshot `gpt-image-2.5-flare-2026-09-08`.

([OpenAI Models](https://developers.openai.com/api/docs/models); [Flare](https://developers.openai.com/api/docs/models/gpt-image-2.5-flare); [Sunburst](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst))

Ikkala model ham HOOKKADR ishlatadigan `POST /v1/images/generations` ni, shuningdek `/v1/images/edits` va `/v1/batch` ni qo'llab-quvvatlaydi. Shuning uchun minimal tuzatish bir qatorli model almashtirishdan iborat. Javobda `data[0].b64_json` avvalgidek qaytishi tasdiqlanmagan, buni smoke test bilan tekshirish kerak. `gpt-image-2` (`gpt-image-2-2026-04-21`) eskirgan deb belgilanmagan, ammo guide "For new integrations, use one of the GPT Image 2.5 models" deydi ([Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)).

Narx tokenlarda hisoblanadi: **rasm kirishi $8/M, rasm chiqishi $30/M, matn kirishi $5/M**, Batch esa yarim narxda ([OpenAI Pricing](https://developers.openai.com/api/docs/pricing)). 2.5 uchun rasmiy "bitta rasm narxi" jadvali yo'q. fal'ning qayta sotuv narxi 1024² da: low $0.006, medium $0.0133, high $0.0528 ([fal GPT Image 2.5](https://fal.ai/gpt-image-2.5)). Shu sababli byudjetni javobdagi `usage` tokenlari bo'yicha hisoblash kerak, qat'iy konstanta bo'yicha emas.

O'lcham qoidalari HOOKKADR uchun muhim ([Image generation guide](https://developers.openai.com/api/docs/guides/image-generation)):

- ikkala tomon 16 ga karrali bo'lishi kerak;
- tomonlar nisbati 1:3 dan 3:1 gacha;
- eng uzun tomon 3840 px dan oshmaydi;
- umumiy piksel soni 655,360 dan 8,294,400 gacha;
- 2560x1440 dan kattasi "experimental" hisoblanadi;
- sifat darajalari: `low`, `medium`, `high`, yangi `xhigh` va `max`;
- `background: "transparent"` 2.5 modellarida ishlaydi.

Hozirgi kod 9:16 va 4:5 uchun `1024x1536` (2:3) yuboradi, natijada rasmni kesishga to'g'ri keladi. Yuqoridagi qoidalarga ko'ra aniq o'lchamlar (hisob-kitob bizniki): 9:16 uchun `864x1536`, 4:5 uchun `1024x1280`, 16:9 uchun `1536x864`.

Bilish kerak bo'lgan cheklovlar ([Image generation guide](https://developers.openai.com/api/docs/guides/image-generation); [Flare](https://developers.openai.com/api/docs/models/gpt-image-2.5-flare)):

- Maskalar "prompt-based", ya'ni model mask shakliga "may not follow its exact shape with complete precision".
- Bir nechta rasm yuborilsa, mask faqat birinchi rasmga qo'llanadi.
- Murakkab so'rov taxminan 2 daqiqagacha cho'zilishi mumkin.
- Rasm modellarini ishlatish uchun tashkilot verifikatsiyasi talab qilinishi mumkin.
- Build tier limiti 20 rasm/daqiqa.

Responses API'dagi `image_generation` tool `previous_response_id` orqali ko'p bosqichli tahrirni va cached-input narxini qo'shimcha beradi. O'zbekiston OpenAI API qo'llab-quvvatlanadigan davlatlar ro'yxatida bor ([OpenAI supported countries](https://developers.openai.com/api/docs/supported-countries)).

**Google.** Google'ning joriy rasm oilasi Nano Banana deb ataladi ([Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation); [Gemini models](https://ai.google.dev/gemini-api/docs/models)):

- **`gemini-nano-banana-2.1`**: 6-oktabr 2026 da GA bo'lgan, Google barcha yangi loyihalar uchun shuni tavsiya qiladi;
- `gemini-3.1-flash-image` (Nano Banana 2);
- `gemini-3.1-flash-lite-image`;
- `gemini-3-pro-image` (Nano Banana Pro);
- eskirgan `gemini-2.5-flash-image`.

2.1 ning narxi har bir o'lchamda 3.1 Flash'ning yarmiga teng ([Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing)):

| Model | 1K | 2K | 4K |
|---|---|---|---|
| `gemini-nano-banana-2.1` | **$0.0336** | **$0.0504** | **$0.113** |
| `gemini-3.1-flash-image` | $0.067 | $0.101 | $0.151 |
| `gemini-3-pro-image` | $0.134 | $0.134 | $0.24 |

Rasm modellari uchun bepul tier yo'q.

Reference rasmlar va parametrlar ([Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation)):

- 2.1 va 3.1 Flash: 10 ta obyekt va 4 ta personaj reference.
- Pro: 6 ta obyekt, 5 ta personaj va 3 ta uslub reference.
- Flash Lite: faqat 1K. U "Not optimized for multiple reference inputs or multi-turn sequential editing".
- `image_size` katta "K" harfi bilan yozilishi shart: kichik harfli "1k" rad etiladi.
- Gemini 3 rasm modellari standart bo'yicha 1K qaytaradi.
- Mask yoki inpainting hujjatlashtirilmagan.
- Barcha natijalarda SynthID bor.
- Rasm ichidagi aniq matn uchun Google `gemini-3-pro-image` ni tavsiya qiladi.

API sathi ham o'zgargan. Rasmiy hujjat endi faqat **Interactions API** ni ko'rsatadi: `POST .../v1beta/interactions`, sozlamalar esa `response_format.aspect_ratio` va `image_size` maydonlarida. `generateContent` lokalizatsiyalangan sahifada "legacy" deb atalgan ([Gemini API (ja)](https://ai.google.dev/gemini-api?hl=ja)). Forumdagi bir foydalanuvchi hisobotiga ko'ra, `generateContent` da `responseModalities: ["IMAGE","TEXT"]` yuborilsa faqat 1K qaytgan. Faqat `IMAGE` yuborilganda esa so'ralgan o'lcham qaytgan ([Google AI forum](https://discuss.ai.google.dev/t/gemini-3-1-flash-image-preview-only-generate-1k-image/142496)). HOOKKADR serveri ham, klienti ham hozir `['TEXT','IMAGE']` yuboradi.

Vertex'dagi mask-tahrir modellari (`imagen-3.0-capability-001/-002`) ham eskirganlar ro'yxatida ([Vertex AI release notes](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/release-notes)). O'zbekiston Gemini API regionlari ro'yxatida bor ([Gemini available regions](https://ai.google.dev/gemini-api/docs/available-regions)).

**Boshqa provayderlar.** Boshqa first-party API'lar ham yetuk:

- BFL'da `/flux-2-pro` "recommended default" hisoblanadi: $0.03/MP, edit $0.045. Yangi `/v1/flux-3-image` 10 tagacha reference va 4K gacha chiqishni qo'llaydi ([BFL generating images](https://docs.bfl.ai/quick_start/generating_images); [BFL pricing](https://docs.bfl.ai/quick_start/pricing); [FLUX 3 overview](https://docs.bfl.ai/flux_3/flux3_overview)).
- Ideogram'da `ideogram-4-5` Precise Edit bor.
- Recraft V4.1 bir rasm uchun $0.035 turadi va OpenAI SDK bilan mos ishlaydi ([Recraft getting started](https://www.recraft.ai/docs/api-reference/getting-started)).

Ularning bitta umumiy muammosi bor: **natija URL'lari tez eskiradi**. BFL imzolangan URL'lari 10 daqiqa, Replicate 1 soat, Recraft taxminan 24 soat yashaydi ([Replicate webhooks](https://replicate.com/docs/topics/webhooks); [Recraft getting started](https://www.recraft.ai/docs/api-reference/getting-started)). Shuning uchun server natijani darhol yuklab olib, o'z omboriga joylashi kerak. BFL API shartlari kirish va chiqish ma'lumotlaridan modellarni o'qitishda foydalanishga ruxsat beradi ([FLUX API Service Terms](https://bfl.ai/legal/flux-api-service-terms)). Bu mijozning hali chiqmagan mahsulot suratlari uchun xavf tug'diradi. Stability AI'ning 2026-yilgi rasmiy hujjatlarini o'qib bo'lmadi ([Stability platform](https://platform.stability.ai/docs/api-reference)), shuning uchun u tavsiya ro'yxatiga kiritilmadi.

**Mahsulotni aniq saqlash.** HOOKKADR uchun eng muhim halollik masalasi mahsulotni, masalan kafel naqshini, piksel darajasida saqlashdir. Hech bir generativ tahrir buni kafolatlamaydi. OpenAI o'z cheklovlari orasida "imperfect character or brand consistency" ni sanaydi. Gemini'da esa umuman mask yo'q. Faqat Ideogram 4.5 Precise Edit "unchanged pixels are copied from the source image" deb va'da beradi ([OpenAI guide](https://developers.openai.com/api/docs/guides/image-generation); [Ideogram Precise Edit 4.5](https://developer.ideogram.ai/v2/api-reference/images/precise-edit/ideogram-4-5.md)).

Demak to'g'ri arxitektura deterministik bo'lishi kerak:

1. Mahsulotni segmentatsiya qilish (Recraft remove background, $0.01) ([Recraft pricing](https://www.recraft.ai/docs/api-reference/pricing)).
2. Faqat fon yoki sahnani generatsiya qilish.
3. Asl mahsulot piksellarini `render_plan.dart` dagi `overlay` orqali qayta joylash.

Ekrandagi matnni AI rasmga "pishirish" o'rniga `drawtext` bilan render qilish ham shu mantiqdan kelib chiqadi: hech bir provayder o'zbek tilidagi matn sifati haqida ma'lumot e'lon qilmaydi.

| Vazifa | Model ID | Narx | Eslatma |
|---|---|---|---|
| Umumiy tezkor rasm | `gpt-image-2.5-flare` | token: $8/M in, $30/M out | Images API, sync, ~2 daqiqagacha |
| Aniq tahrir, reference'lar | `gpt-image-2.5-sunburst` | xuddi shu token narxi | `/v1/images/edits`, mask birinchi rasmga |
| Arzon Google default | `gemini-nano-banana-2.1` | 1K $0.0336 | 10 obyekt + 4 personaj ref |
| Rasm ichidagi matn | `gemini-3-pro-image` | 1K/2K $0.134 | Google tavsiyasi |
| Eng arzon 1K | `gemini-3.1-flash-lite-image` | 1K $0.0336 | multi-ref uchun emas |
| Pikselni saqlovchi tahrir | Ideogram `ideogram-4-5` Precise Edit | e'lon qilinmagan (`dry_run` narx beradi) | o'zgarmagan piksellar nusxalanadi |
| **Ishlatmang** | `gpt-image-1`, `gpt-image-1-mini`, `gpt-image-1.5`, `chatgpt-image-latest`, `dall-e-*`, `imagen-*`, `gemini-2.5-flash-image-preview`, `gemini-3-pro-image-preview`, `gemini-3.1-flash-image-preview` | — | o'chirilgan yoki o'chirilmoqda |

## Video generatsiya: Sora yopildi, Veo 3.1 Preview'da qoldi, Omni Flash yangi default

**Veo 3.1 (Gemini API).** `veo-3.1-generate-preview` Gemini API'da hali ishlaydi va narxlangan, lekin u Preview modeli. Gemini API'da Veo 3.1 uchun GA `-001` ID yo'q, `veo-3.0-*-001` esa eskirgan ([Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo); [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)).

Cheklovlar ([Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)):

- davomiylik **4, 6 yoki 8 soniya**; 1080p, 4K, reference rasmlar va extension uchun **8 s majburiy**;
- resolution: 720p (standart), 1080p, 4K;
- aspect ratio faqat 16:9 va 9:16; 24 fps;
- bitta so'rovda bitta video; matn 1,024 tokendan oshmaydi;
- audio "always on";
- kirishlar: birinchi kadr uchun `image`, `lastFrame`, 3 tagacha `referenceImages`, extension uchun `video`;
- extension har safar 7 s qo'shadi, 20 martagacha, umumiy maksimum 148 s. Bu faqat 720p da va faqat oxirgi 2 kunda yaratilgan videolar uchun ishlaydi;
- videolar serverda **2 kun** saqlanadi;
- kechikish 11 soniyadan 6 daqiqagacha.

Narx soniyasiga, audio bilan. Faqat muvaffaqiyatli natija uchun to'lanadi ([Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)):

| Model | 720p | 1080p | 4K |
|---|---|---|---|
| `veo-3.1-generate-preview` | $0.40 | $0.40 | $0.60 |
| `veo-3.1-fast-generate-preview` | $0.10 | $0.12 | $0.30 |
| `veo-3.1-lite-generate-preview` | $0.05 | $0.08 | — |

GA va SLA kerak bo'lsa, Vertex (endi Gemini Enterprise Agent Platform) da `veo-3.1-generate-001` bor. Lekin u faqat `us-central1` regionida ishlaydi, limiti 50 RPM, retirement sanasi esa "November 17, 2026 or later" ([Vertex Veo 3.1](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate)).

**Gemini Omni Flash.** Google'ning video hujjati endi "Use Gemini Omni Flash as your default model for video generation" deydi ([Gemini API video overview](https://ai.google.dev/gemini-api/docs/video)). **`gemini-omni-1.1-flash`** (stable) imkoniyatlari ([Gemini Omni Flash model page](https://ai.google.dev/gemini-api/docs/models/gemini-omni-flash); [Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)):

- 3–10 s video;
- 360p dan 4K gacha (1080p va 4K upscale qilinadi), 16:9 va 9:16, 24 fps;
- raqamlangan reference rasmlar, birinchi va oxirgi kadr;
- 3 tagacha video reference;
- 10 s gacha yuklangan videoni tahrirlash va uzaytirish.

U Veo'dan farqli o'laroq **Interactions API** orqali ishlaydi va 720p da taxminan **$0.10/s** turadi ([Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)). HOOKKADR uchun muhim cheklov: "English is fully supported. Other languages are untested". Demak o'zbekcha dialog sifatiga hech kim kafolat bermaydi ([Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)).

**Boshqa provayderlar.** OpenAI'da endi video yo'q: "The Sora 2 models and Videos API were shut down on September 24, 2026 … No one-to-one replacement API is available" ([OpenAI video generation guide](https://developers.openai.com/api/docs/guides/video-generation)).

Runway API endi 47 modelli katalogga aylangan ([Runway API models](https://docs.dev.runwayml.com/guides/models/); [Runway API pricing](https://docs.dev.runwayml.com/guides/pricing/)):

- o'z modellari: `gen4.5` ($0.12/s), `gen4_turbo` ($0.05/s), `aleph2` (video-to-video tahrir, $0.28/s);
- qayta sotiladigan modellar: `veo3.1` (audio bilan $0.40/s, audiosiz $0.20/s), `seedance2`, `hailuo3`, `wan3` va `gemini_omni_flash_1.1`.

Boshqa variantlar ([MiniMax video guide](https://platform.minimax.io/docs/guides/video-generation); [MiniMax pricing](https://platform.minimax.io/docs/guides/pricing-paygo); [fal: Seedance 2.5 vs 2.0](https://fal.ai/learn/devs/seedance-2-5-vs-seedance-2-0); [Luma Agents models guide](https://docs.agents.lumalabs.ai/guides/model/)):

- `MiniMax-H3`: 4–15 s, 768P yoki 2K, $0.08/s (768P), 9 tagacha reference rasm.
- Seedance `dreamina-seedance-2-0-260128`: 4–15 s, 4K gacha, 12 tagacha aralash reference. fal orqali 720p da taxminan $0.30/s.
- Luma `ray-3.2`: faqat yangi Agents API'da, 5 yoki 10 s, 1080p gacha.
- Kling 3.0: rasmiy hujjatlari JavaScript bilan render qilinadi, shuning uchun `model_name` satrlari birlamchi manbadan tasdiqlanmadi. fal orqali `fal-ai/kling-video/v3/pro/text-to-video` audio o'chiq bo'lsa $0.112/s, yoqilgan bo'lsa $0.168/s turadi ([fal Kling v3 Pro](https://fal.ai/models/fal-ai/kling-video/v3/pro/text-to-video)).

**Haqiqiy yuzlar.** Bu video generatsiyadagi asosiy to'siq:

- Veo'da image-to-video va reference rasmlar faqat `personGeneration: "allow_adult"` ni qabul qiladi. EU, UK, CH va MENA hududlarida esa hamma rejimda faqat `allow_adult` ruxsat etilgan ([Gemini API Veo docs](https://ai.google.dev/gemini-api/docs/veo)).
- Omni Flash "certain recognizable people" ni bloklaydi va EEA, CH, UK da yuklangan videoni tahrirlashga ruxsat bermaydi ([Gemini Omni docs](https://ai.google.dev/gemini-api/docs/omni)).
- Seedance 2.0 reference'dagi real yuzlarni rad etadi. Bu uchinchi tomon manbasidan ma'lum ([Adobe community](https://community.adobe.com/questions-404/reference-content-can-t-include-real-human-faces-when-using-seedance-2-0-and-seedance-2-0-fast-1631867)).

**Async ishlash va saqlash.** Barcha provayderlar "job yaratish → poll yoki webhook → yuklab olish" naqshida ishlaydi, lekin natijalar qisqa muddat saqlanadi: Veo 2 kun, Luma Agents presigned URL'lari 1 soat, MiniMax task ro'yxati 7 kun ([Luma Agents API](https://docs.agents.lumalabs.ai/); [MiniMax video guide](https://platform.minimax.io/docs/guides/video-generation)). Bundan server uchun quyidagi talablar kelib chiqadi:

- provider, tashqi ID, status va muddat saqlanadigan job jadvali;
- taxminan 10 s dan boshlanadigan backoff bilan poll qilish;
- natijani darhol o'z bucket'iga ko'chirish.

**Audio va fps.** Veo audiosini Gemini API orqali o'chirib bo'lmaydi. Shuning uchun HOOKKADR uni alohida stem sifatida ko'rishi kerak: voiceover ostida pasaytirish yoki butunlay o'chirish. fps faqat Google modellarida hujjatlashtirilgan, shuning uchun FFmpeg timeline'da har doim umumiy fps'ga qayta kodlash kerak.

| Daraja | Model ID | Davomiylik / sifat | Narx (720p, audio bilan) | Kirish yo'li |
|---|---|---|---|---|
| Qoralama | `veo-3.1-lite-generate-preview` | 4/6/8 s; 720p, 1080p | $0.05/s | Gemini `predictLongRunning` |
| Standart | `veo-3.1-fast-generate-preview` | 4/6/8 s; 4K gacha | $0.10/s | Gemini `predictLongRunning` |
| Standart + tahrir | `gemini-omni-1.1-flash` | 3–10 s; 360p–4K | ~$0.10/s | Gemini Interactions API |
| Premium | `veo-3.1-generate-preview` | 4/6/8 s; 4K gacha; 3 ta ref | $0.40/s | Gemini `predictLongRunning` |
| GA / SLA | `veo-3.1-generate-001` | 4/6/8 s; bir promptda 4 video | Vertex narxi | Vertex, faqat `us-central1` |
| Ko'p reference | `dreamina-seedance-2-0-260128` | 4–15 s; 4K gacha | ~$0.30/s (fal) | BytePlus ModelArk yoki fal |
| Arzon muqobil | `MiniMax-H3` | 4–15 s; 768P/2K | $0.08/s (768P) | MiniMax `/v2/video_generation` |
| **Ishlatmang** | `sora-2`, `sora-2-pro`, `veo-3.0-*-001` | yopilgan yoki eskirgan | — | — |

## Render dvigateli: LGPL FFmpeg fork qoladi, native yo'l keyin keladi

**Fork holati.** Asl arthenica/ffmpeg-kit repo'si **2-iyul 2026 da arxivlangan**. README'da "FFmpegKit has been officially retired" deb yozilgan ([GitHub arthenica/ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit)). Endi amaldagi Flutter variantlari jamoat fork'laridir. HOOKKADR'ning `pubspec.yaml:10` dagi `ffmpeg_kit_flutter_new_full: ^2.5.7` ular orasida eng to'g'ri tanlov ([pub.dev ffmpeg_kit_flutter_new_full](https://pub.dev/packages/ffmpeg_kit_flutter_new_full)):

- 2.5.7 versiyasi taxminan 6-oktabr 2026 da chiqqan;
- **FFmpeg 8.1.2, LGPL-3.0, "contains no GPL components"**;
- SPM va CocoaPods qo'llab-quvvatlanadi;
- VideoToolbox va MediaCodec bor.

Eng xavfli tuzoq paket nomida. Asosiy `ffmpeg_kit_flutter_new` paketi aslida **full-gpl** varianti: unda x264, x265, xvidcore va vid.stab bor, va "apps using it are distributed under GPL 3.0" ([pub.dev ffmpeg_kit_flutter_new](https://pub.dev/packages/ffmpeg_kit_flutter_new)). AI agentlar "yangiroq paket" deb unga o'tib ketmasligi uchun bu master prompt'da aniq yozilishi kerak.

Fork'ni bitta shaxs yuritadi va GitHub'dagi Releases bo'limi bo'sh ([GitHub sk3llo/ffmpeg_kit_flutter](https://github.com/sk3llo/ffmpeg_kit_flutter)). Shuning uchun `^` o'rniga aniq versiyani pin qilish va XCFramework/AAR'larni keshlash oqilona. FFI asosidagi `ffmpeg_kit_extended_flutter` 0.6.2 zaxira manba bo'la oladi, lekin u hali 0.x bosqichida ([pub.dev ffmpeg_kit_extended_flutter](https://pub.dev/packages/ffmpeg_kit_extended_flutter)).

**GPL filtrlari va patentlar.** FFmpeg'ning LICENSE.md fayli quyidagilarni sanaydi ([FFmpeg LICENSE.md](https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/LICENSE.md)):

- GPL-only filtrlar: **`eq`**, `boxblur`, `hqdn3d`, `delogo`, `perspective`, `smartblur`, `cropdetect`, `mpdecimate` va boshqalar;
- GPL tashqi kutubxonalar: `libx264`, `libx265`, `libvidstab`, `libxvid`;
- nonfree (tarqatib bo'lmaydigan): FDK AAC va OpenSSL.

`render_plan.dart` ishlatadigan filtrlar bu ro'yxatda yo'q: `xfade`, `zoompan`, `drawtext`, `lutyuv`, `hue`, `colorbalance`, `overlay`, `sidechaincompress`, `amix`. Demak rang grade'i bundan keyin ham `eq` ga emas, `lutyuv`/`hue`/`colorbalance` ga tayanishi shart.

Repo build artefaktlarini lokal tekshirish quyidagini ko'rsatdi:

- iOS build'dagi FFmpeg dinamik framework'lar sifatida keladi, bitta arxitektura uchun taxminan 31 MB;
- configure qatorida `--enable-gpl` yo'q;
- lekin **`--enable-version3` va `--enable-libopenh264` bor**.

Cisco faqat o'zi tarqatgan OpenH264 binary uchun royalti to'laydi, manbadan kompilyatsiya qilingan nusxa uchun emas ([OpenH264 FAQ](https://www.openh264.org/faq.html)). `render_service.dart:85` hozir `h264_videotoolbox` va `h264_mediacodec` dan foydalanadi. Bu to'g'ri yo'l. Xato bo'lganda hech qachon `libopenh264` yoki `libx264` ga o'tmaslik ham yozma qoidaga aylanishi kerak. FFmpeg o'zi hech qanday patent litsenziyasi bermasligini ochiq aytadi ([ffmpeg.org/legal.html](https://ffmpeg.org/legal.html)). OS enkoderini chaqiradigan ilovani OS vendorining kodek litsenziyasi qoplashini tasdiqlovchi birlamchi manba topilmadi. Bu savolga advokat javob berishi kerak.

**LGPL talablari.** ffmpeg.org/legal.html talablari aniq ([ffmpeg.org/legal.html](https://ffmpeg.org/legal.html)):

- `--enable-gpl` va `--enable-nonfree` siz build;
- dinamik bog'lash;
- aynan shu binary'ning manba kodi va configure qatorini e'lon qilish;
- About yoki litsenziyalar ekranida atribusiya;
- EULA'dan reverse engineering taqiqini olib tashlash;
- kutubxona nomlarini o'zgartirmaslik.

LGPLv3'ning "Installation Information" bandi iOS code signing bilan qanday bog'lanishi bo'yicha 2012-yildan keyingi birlamchi manba topilmadi. Bu ham advokat xulosasini talab qiladi.

**16 KB sahifa.** Google Play **1-fevral 2027** dan boshlab 16 KB sahifa o'lchamini qo'llab-quvvatlamaydigan yangilanishlarni qabul qilmaydi ([Android page sizes](https://developer.android.com/guide/practices/page-sizes)). Lokal keshdagi eski AAR (2.2.3) segmentlari `2**14` ga tekislangan, ya'ni mos. Ammo pin qilingan 2.5.7 versiyani alohida qayta tekshirish kerak.

**Audio kodek.** `render_plan.dart:283` FFmpeg'ning ichki `aac` dasturiy enkoderidan foydalanadi. iOS'da `aac_at` (AudioToolbox) audio kodlashni ham OS ichida qoldiradi. Bu research yozuvlaridagi taxmin, sinab ko'rish kerak.

**Native dvigatellar.** Native dvigatellar preview va eksport paritetini arxitektura darajasida ta'minlaydi, lekin to'liq almashtirish uchun hali erta.

- **iOS:** `customVideoCompositorClass` o'rnatilgan bitta `AVVideoComposition` uchta narsani bir xil boshqaradi: `AVPlayerItem` preview, `AVAssetImageGenerator` thumbnail va `AVAssetExportSession` eksport ([Apple AVVideoCompositing](https://developer.apple.com/documentation/avfoundation/avvideocompositing)). iOS 26+ da `BGContinuedProcessingTask` foydalanuvchi boshlagan eksportni fonda davom ettiradi ([Apple BGContinuedProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask)). Lekin HOOKKADR'ning minimal versiyasi iOS 16.
- **Android:** Media3 versiyasi **1.11.1 (10-sentabr 2026)**. Transformer API 23+ da ishlaydi, bitta `Composition` ham `CompositionPlayer` preview, ham eksport uchun xizmat qiladi. Biroq CompositionPlayer hali `@ExperimentalApi`, bir nechta video ketma-ketlikli preview "in active development". Eng muhimi, **"Crossfading video or audio tracks is not yet supported"**, ya'ni `xfade` ning tayyor ekvivalenti yo'q ([Media3 release notes](https://developer.android.com/jetpack/androidx/releases/media3); [Composition](https://developer.android.com/media/media3/transformer/composition); [CompositionPlayer](https://developer.android.com/media/media3/transformer/compositionplayer)).
- **Fon eksporti (Android):** Android 15+ da `mediaProcessing` FGS bor, uning byudjeti 24 soatda 6 soat. Android 11–14 uchun siyosatga mos FGS turi manbalarda hal qilinmagan ([FGS service types](https://developer.android.com/develop/background-work/services/fgs/service-types)).

**Tijoriy SDK'lar.** Ikkala variant ham UI-birinchi editorlar:

- IMG.LY `imgly_editor`: har bir platforma uchun alohida litsenziya, narx so'rov bo'yicha ([IMG.LY pricing](https://img.ly/pricing.md)).
- Banuba `ve_sdk_flutter`: MAU bo'yicha yillik litsenziya, standart eksport FHD, 4K faqat proof-of-concept ([Banuba pricing guide](https://www.banuba.com/blog/banuba-video-editor-sdk-pricing-guide)).

Ularning hech birida Dart'dan AI yozgan `EditPlan` ni headless bajarish imkoniyati tasdiqlanmagan.

**Tavsiya etilgan yo'l:**

1. `EditPlan` ni versiyalangan `RenderGraph` IR'ga kompilyatsiya qilish; FFmpeg uning hozirgi backend'i bo'lib qoladi.
2. Preview'da grade matematikasini Impeller `ImageFilter.shader` ga 1:1 ko'chirish. Bu filtr faqat Impeller'da ishlaydi ([Flutter fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)).
3. SSIM asosidagi golden-frame testlar qo'shish.
4. Keyinroq AVFoundation va Media3 backend'larini shu IR orqasiga qo'shish.

## O'zbek tili: so'z-timestamp'li STT faqat ikki hosted provayderda bor

**STT (nutqni matnga).**

- **ElevenLabs Scribe v2** o'zbekchani (`uzb`) "Good (>10% to ≤20% WER)" darajasida ro'yxatga oladi. U so'z darajasidagi timestamp, 32 tagacha spikerli diarization va keyterm prompting beradi. Narxi **$0.22/soat**, realtime rejimda $0.39/soat. Vendor FLEURS'da 15.9% WER deb da'vo qiladi ([ElevenLabs STT docs](https://elevenlabs.io/docs/capabilities/speech-to-text); [ElevenLabs API pricing](https://elevenlabs.io/pricing/api); [ElevenLabs Uzbek STT](https://elevenlabs.io/speech-to-text/uzbek)).
- **Azure AI Speech** `uz-UZ` ni "Uzbek (Latin, Uzbekistan)" deb belgilaydi. Fast transcription `words[]` massivida `offsetMilliseconds` bilan so'z timestamp'larini va mono audio uchun 2–35 spikerli diarization beradi. Fayl 5 soat yoki 500 MB gacha. Narx $0.36/soat, 1-sentabr 2026 dan esa promo meter **$0.10/soat** ([Azure language support](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=stt); [Azure fast transcription](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/fast-transcription-create); [Azure Retail Prices API](https://prices.azure.com/api/retail/prices)).
- **Google Chirp 3** da `uz-UZ` faqat Preview. So'z timestamp'lari bo'yicha hujjat o'ziga zid, o'zbekcha esa diarization ro'yxatida yo'q ([Chirp 3 docs](https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3)).

Quyidagilar o'zbekcha uchun yaroqsiz:

- OpenAI'ning til ro'yxatida o'zbekcha yo'q, `timestamp_granularities[]` esa faqat `whisper-1` da ishlaydi ([OpenAI STT guide](https://developers.openai.com/api/docs/guides/speech-to-text)).
- Deepgram'da o'zbekcha yo'q ([Deepgram](https://developers.deepgram.com/docs/models-languages-overview)).
- AssemblyAI o'zbekchani faqat Universal-2 modelida, ">50% WER" guruhida beradi ([AssemblyAI](https://www.assemblyai.com/docs/pre-recorded-audio/supported-languages)).

Bu provayderlarni UI'da "o'zbekcha subtitr" deb ko'rsatish loyihaning halollik qoidasini buzadi.

Ikki chegaraviy holat bor. Gemini audio faqat `MM:SS` formatidagi segment timestamp beradi, so'z darajasida emas. Shuning uchun u faqat imlo va tinish belgilarini tuzatadigan ikkinchi bosqich bo'la oladi ([Gemini audio understanding](https://ai.google.dev/gemini-api/docs/audio)). Mahalliy startap Aisha'ning API hujjatida `has_offset` "segment offsets" qaytaradi, so'z darajasidagi emas, garchi marketing sahifasi boshqacha da'vo qilsa ham ([Aisha llms-api.txt](https://aisha.group/llms-api.txt)).

**Ochiq modellar va qurilmada ishlash.**

- `navai-uz/whisper-medium-uzbek` litsenziya jihatidan eng xavfsiz: Apache-2.0, 753 soat ma'lumotda o'qitilgan, macro WER 9.73, lotin yozuvida chiqaradi va apostroflarni okina'ga yig'adi ([model card](https://huggingface.co/navai-uz/whisper-medium-uzbek)).
- `idrock/piyola-v2` FLEURS'da 10.67 WER bilan kuchliroq. Lekin u CC-BY-4.0 litsenziyasida va tinish belgisi, katta harf va raqamlarsiz chiqaradi ([model card](https://huggingface.co/idrock/piyola-v2)).
- Qurilmada whisper.cpp (MIT) ikkala platformada ishlaydi. WhisperKit wrapper'larida esa Android yo'q ([whisper.cpp](https://github.com/ggml-org/whisper.cpp); [flutter_whisper_kit](https://pub.dev/documentation/flutter_whisper_kit/latest/)).

Barcha WER raqamlarini vendorlarning o'zi e'lon qilgan. HOOKKADR o'z ichki benchmark'ini o'tkazishi kerak: 30–60 daqiqalik telefon mikrofoni yozuvlari, musiqa ostidagi nutq va o'zbek-rus aralash nutqda.

**TTS (matnni nutqqa).**

- ElevenLabs'da tuzoq bor. O'zbekchani faqat **Eleven v3, v4, v4 Turbo va v3 Conversational** qo'llaydi ($0.08/1K belgi). Mashhur `Multilingual v2` va `Flash v2.5` modellarining ro'yxatida o'zbekcha **yo'q** ([ElevenLabs models](https://elevenlabs.io/docs/overview/models); [ElevenLabs API pricing](https://elevenlabs.io/pricing/api)).
- Azure'da ikkita Standard ovoz bor: **`uz-UZ-MadinaNeural`** (ayol) va **`uz-UZ-SardorNeural`** (erkak), $15/1M belgi. Fonema, custom lexicon va viseme qo'llanmaydi, HD variant ham yo'q ([Azure TTS language support](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts)).
- Gemini API'da `gemini-3.8-flash-tts` va `gemini-3.8-flash-lite-tts` "Northern Uzbek" ni qo'llaydi ([Gemini speech generation](https://ai.google.dev/gemini-api/docs/speech-generation)).
- Yandex'da faqat uchta ayol ovozi bor: `nigora`, `zamira`, `yulduz` ([Yandex voices](https://aistudio.yandex.ru/docs/en/speechkit/tts/voices)).
- Google Cloud TTS va OpenAI TTS o'zbekchani ro'yxatga olmaydi ([Cloud Gemini-TTS](https://docs.cloud.google.com/text-to-speech/docs/gemini-tts); [OpenAI TTS guide](https://developers.openai.com/api/docs/guides/text-to-speech)).
- Meta MMS-TTS faqat kirill yozuvini qabul qiladi va CC-BY-NC, ya'ni notijoriy litsenziyada ([MMS-TTS](https://huggingface.co/facebook/mms-tts-uzb-script_cyrillic)).

O'zbekcha ovoz klonlash amalda faqat ElevenLabs Professional Voice Cloning orqali mumkin. U ovoz egasining o'z mikrofonidan o'tadigan verifikatsiyani talab qiladi va "Even with their consent, you cannot clone someone else's voice" deydi ([ElevenLabs voice cloning](https://elevenlabs.io/docs/product-guides/voices/voice-cloning)). Azure personal voice `uz-UZ` ni qo'llamaydi.

**Musiqa.**

- **Eleven Music** eng aniq huquqiy asosga ega: model `music_v2_5`, 3 soniyadan 5 daqiqagacha, instrumental rejim bor, $0.15/daqiqa, Starter+ rejalarda tijoriy litsenziya, "cleared for nearly all commercial uses" ([ElevenLabs Music docs](https://elevenlabs.io/docs/capabilities/music)).
- Google Lyria (`lyria-3-clip-preview` 30 s, `lyria-3.5` to'liq qo'shiq) SynthID bilan belgilanadi, lekin hujjat sahifasida tijoriy huquq haqida hech narsa yozilmagan ([Gemini music generation](https://ai.google.dev/gemini-api/docs/music-generation)).
- Stable Audio Community License bo'yicha tijoriy foydalanish faqat yillik daromad $1M dan kam bo'lganda bepul ([Stability explainer](https://stability.ai/explainers/stable-audio-vs-competitors-licensing-export-rights-and-self-hosting-compared)).
- Suno'ning rasmiy self-serve API'si yo'q va WMG bilan kelishuvdan keyin litsenziyalangan modellarga o'tmoqda ([Sonilo](https://sonilo.com/blog/guides/official-suno-api-saas-builders-2026); [Billboard](https://billboard.com/pro/suno-warner-music-sign-ai-licensing-deal-settle-lawsuit/)).

Beat detection uchun librosa (ISC) serverda xavfsiz. aubio (GPL-3.0) va essentia (AGPL-3.0) ilova binary'siga kiritilmasligi kerak ([librosa](https://github.com/librosa/librosa); [aubio](https://github.com/aubio/aubio); [essentia](https://github.com/MTG/essentia)).

**Ovoz balandligi va tozalash.** `render_plan.dart` hozir `sidechaincompress` bilan musiqani pasaytiradi, lekin yakuniy **loudness normalizatsiyasi umuman yo'q**. FFmpeg `loudnorm` ikki bosqichli linear rejimni qo'llaydi. Uning standart qiymatlari I=-24 va TP=-2, dynamic rejimda esa audioni 192 kHz ga oshiradi, shuning uchun chiqish sample rate'ini aniq ko'rsatish kerak ([FFmpeg filters](https://ffmpeg.org/ffmpeg-filters.html)). Ijtimoiy tarmoqlar uchun -14 LUFS / -1 dBTP keng tarqalgan nishon, ammo platformalarning rasmiy spetsifikatsiyasi topilmadi ([instagit](https://instagit.com/browser-use/video-use/social-media-loudness-normalization-targets/)). Nutqni tozalash uchun `afftdn` ichki filtr bo'lib, qo'shimcha fayl talab qilmaydi. `arnndn` esa model faylini talab qiladi, eng ko'p ishlatiladigan model to'plamida esa litsenziya e'lon qilinmagan ([rnnoise-models](https://github.com/GregorR/rnnoise-models)).

**Yozuv va alifbo.** Bu masala ikki qatlamli.

Birinchi qatlam — hozirgi lotin alifbosi. Unda oʻ va gʻ U+02BB bilan, tutuq belgisi U+02BC bilan yoziladi. Amalda esa U+2018, U+2019 va ASCII `'` aralash ishlatiladi ([Wikipedia: Uzbek alphabet](https://en.wikipedia.org/wiki/Uzbek_alphabet)). Shuning uchun subtitrlar uchun normalizatsiya funksiyasi kerak:

1. matnni NFC shakliga keltirish;
2. kirill harflari topilsa, lotinga transliteratsiya qilish;
3. apostroflarni U+02BB yoki U+02BC ga yig'ish.

Lokal tekshiruvda caption shrifti `assets/fonts/Inter.ttf` da U+02BB, U+02BC hamda Ö, Ğ, Ş, Ç glif'lari borligi aniqlandi.

Ikkinchi qatlam — yangi alifbo qonuni:

- Qonunchilik palatasi uni 7-iyul 2026 da qabul qilgan.
- Senat 10-sentabrda ma'qullagani xabar qilingan. O'zgarishlar: Oʻ→Ö, Gʻ→Ğ, Sh→Ş, Ch→Ç.
- Qonun 2027 da kuchga kirsa, darsliklar 2027–2031 yillarda yangi alifboga o'tadi.
- 14-oktabr holatiga prezident imzosi haqida xabar yo'q.
- Zamin.uz Senat ma'qullaganini rasmiy manbada tasdiqlay olmagan.

([Kun.uz](https://kun.uz/en/news/2026/07/07/parliaments-lower-house-passes-bill-to-revise-uzbek-alphabet-848eb2); [Times of Central Asia](https://timesca.com/uzbekistan-latin-alphabet-changes-senate/); [Zamin.uz](https://zamin.uz/en/uzbekistan/220835-o-va-g-endi-boshqacha-yoziladimi-senat-alifbo-islohotiga-oid-qonunni-maqulladi.html))

Rasmiy e'londan oldin standartni o'zgartirmaslik kerak, lekin "yangi alifbo" chiqish rejimini dizaynga oldindan kiritib qo'yish oqilona.

## Do'kon va qonun: rozilik ekrani, shikoyat tugmasi va serverda C2PA imzosi

**Apple.** Apple'da alohida "generative AI" bandi yo'q. Lekin 2025-noyabr tahririda qo'shilgan **5.1.2(i)** bandi to'g'ridan-to'g'ri HOOKKADR'ga tegishli: "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so" ([Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/); [TechCrunch](https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai)).

Hozir kodda faqat bitta rozilik bor: `app_controller.dart:199` dagi `consent_gemini`. Uning kamchiliklari:

- u faqat chat'da Gemini video tahlilidan oldin so'raladi;
- uni bekor qilib bo'lmaydi, chunki `setGeminiConsent` faqat `true` yozadi;
- Claude, OpenAI va kelajakdagi ElevenLabs uchun rozilik umuman yo'q.

5.1.1(ii) esa rozilikni qaytarib olish yo'lini ham talab qiladi.

Boshqa majburiy bandlar ([Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)):

- 3.1.1: kreditlar faqat IAP orqali sotiladi va "may not expire";
- 4.8: Google Sign-In bo'lsa, maxfiylikni saqlaydigan ekvivalent login ham bo'lishi kerak (Sign in with Apple bu shartga mos keladi);
- 5.1.1(v): ilova ichida akkauntni o'chirish imkoniyati;
- 2.1: ishlaydigan demo akkaunt va yoqilgan backend.

**Google Play.** Play'ning AI-Generated Content siyosati text-to-image ilovalarni va real odamlarning video yoki ovozini yaratadigan ilovalarni qamraydi. U **"in-app user reporting or flagging features"** ni talab qiladi, ya'ni foydalanuvchi ilovadan chiqmasdan shikoyat yubora olishi kerak ([Play Console Help 13985936](https://support.google.com/googleplay/android-developer/answer/13985936); [Play Console Help 14094294](https://support.google.com/googleplay/android-developer/answer/14094294)). Repo'da AI natijalari uchun bunday tugma topilmadi.

25-avgust 2026 dagi blog talablarni qayta ta'kidlaydi ([Android Developers Blog](https://android-developers.googleblog.com/2026/08/ensuring-safety-genai-preventing-non-consensual-intimate-content.html)):

- reviewer'lar AI funksiyalariga paywall va geo-fence'siz to'liq kira olishi kerak;
- "nudify", "undress" va deepfake so'rovlari rad etilishini isbotlovchi xavfsizlik test hujjati tayyor bo'lishi kerak;
- faqat model filtrlariga emas, o'zingizning kirish va chiqish moderatsiyangizga tayanish kerak;
- NCII sababli o'chirilgan ilovalar monetizatsiyadan bloklanadi.

Kreditlar virtual valyuta sifatida Play Billing orqali sotiladi va faqat shu ilova ichida ishlatiladi. Keng `READ_MEDIA_*` ruxsati o'rniga Android photo picker ishlatilishi kerak ([Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738); [Photo and Video Permissions](https://support.google.com/googleplay/android-developer/answer/14115180)). Moderatsiya uchun OpenAI `omni-moderation-latest` bepul. Lekin rasmlarda faqat sexual, violence va self-harm toifalari ishlaydi, va u CSAM detektori emas ([OpenAI Moderation](https://developers.openai.com/api/docs/guides/moderation)).

**Provenance (kelib chiqishni belgilash).** Provayderlar o'z natijalarini belgilaydi:

- Gemini rasm, Veo va Omni natijalarida SynthID bor;
- Vertex Veo'da C2PA bor;
- OpenAI C2PA ustiga SynthID qo'shayotganini aytadi.

([Gemini image generation](https://ai.google.dev/gemini-api/docs/image-generation); [Vertex Veo 3.1](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/veo/3-1-generate); [OpenAI provenance](https://openai.com/index/understanding-the-source-of-what-we-see-and-hear-online))

Ammo **FFmpeg decode va qayta encode qilganda C2PA manifesti o'chib ketadi**, SynthID esa bunga chidamli qilib ishlab chiqilgan ([Creative AI News](https://www.creativeainews.com/articles/content-credentials-export-survival-test-2026/); [SSL.com](https://www.ssl.com/article/preserving-c2pa-manifests-across-the-media-production-workflow/)). Demak HOOKKADR yakuniy MP4'ni o'zi imzolashi kerak. c2pa-rs MP4, MOV va JPEG formatlarini qo'llaydi, `c2pa_flutter` 0.1.0 esa faqat rasm formatlarini sanaydi ([c2pa-node supported formats](https://opensource.contentauthenticity.org/docs/c2pa-node-v2/supported-formats); [pub.dev c2pa_flutter](https://pub.dev/packages/c2pa_flutter)). Shuning uchun imzo server tomonda qo'yiladi: kalit KMS'da saqlanadi, sertifikat esa C2PA trust list'dagi CA'dan olinadi.

YouTube C2PA metadata'si bor kontentni avtomatik belgilaydi va bu belgini keyin o'zgartirib bo'lmaydi. Shu bilan birga rang tuzatish, subtitr va avtomatik kesish kabi AI-yordamchi tahrirlar oshkor qilish majburiyatidan ozod ([YouTube Help](https://support.google.com/youtube/answer/14328491)). Shuning uchun manifest `trainedAlgorithmicMedia` yoki `compositeWithTrainedAlgorithmicMedia` ni faqat natijada haqiqatan generativ media bo'lganda e'lon qilishi kerak. ElevenLabs o'z watermark'larini olib tashlashni taqiqlaydi ([ElevenLabs Use Policy](https://elevenlabs.io/use-policy)).

**EU AI Act.** 50-modda **2-avgust 2026** dan qo'llanadi ([AI Act Explorer Art. 50](https://artificialintelligenceact.eu/article/50/)):

- 50(2): sintetik audio, rasm va videoni machine-readable shaklda belgilash;
- 50(4): deepfake'larni oshkor qilish;
- 50(5): bu ma'lumotni birinchi o'zaro ta'sirdayoq berish.

Ikkilamchi manbalarga ko'ra, Digital Omnibus 50(2) bandini faqat 2-avgustdan oldin bozorda bo'lgan tizimlar uchun **2-dekabr 2026** gacha kechiktirgan. Yangi tizimlar esa bozorga chiqqan kundan rioya qilishi kerak. Jarima €15M yoki global aylanmaning 3% igacha ([CSA research note](https://labs.cloudsecurityalliance.org/research/csa-research-note-eu-ai-act-article50-watermarking-deadline/)). Komissiya 10-iyun 2026 da ixtiyoriy Code of Practice e'lon qilgan. Unda hech bir texnika to'rt mezonning barchasiga javob bermasligi tan olingan, ya'ni qatlamli yondashuv kerak ([Jones Day](https://www.jonesday.com/en/insights/2026/06/european-commission-publishes-final-code-of-practice-on-marking-and-labelling-aigenerated-content)). Agar HOOKKADR o'z brendi ostida EU foydalanuvchilariga generatsiya taklif qilsa, u 50(2) bo'yicha "provider" hisoblanishi ehtimoli bor. Buni advokat tasdiqlashi kerak.

**O'zbekiston.** **ZRU-547 "Shaxsga doir ma'lumotlar to'g'risida"** qonunining 27-1-moddasi **ZRU-1125 (26-mart 2026)** bilan o'zgartirilgan ([lex.uz ZRU-547](https://lex.uz/docs/4396419)):

- endi faqat biometrik, genetik va O'zbekistondagi telekom operatorlari foydalanuvchilarining ma'lumotlari mahalliy saqlanishi va Davlat reestrida ro'yxatdan o'tishi shart;
- boshqa ma'lumotlarni xorijda saqlash mumkin, agar uchta shartdan biri bajarilsa: davlat adekvat davlatlar ro'yxatida bo'lsa, tasdiqlangan standart shartlar yoki BCR qo'llansa, yoki ro'yxatdagi xalqaro standartlarga rioya qilinsa;
- maxsus ma'lumotlar uchun yozma rozilik kerak, u elektron bo'lishi mumkin;
- transchegaraviy uzatish subyekt roziligi bilan ham ruxsat etiladi.

**ZRU-1115 (21-yanvar 2026)** AI qonuni sun'iy intellekt yordamida shaxsiy ma'lumotlarni noqonuniy qayta ishlash uchun 50–100 BHM jarima va musodara belgilagan. Lekin lex.uz'dagi yakuniy matnda AI kontentini belgilash majburiyati yo'q. Bu loyiha bosqichidagi matbuot xabarlariga zid ([lex.uz ZRU-1115](https://lex.uz/docs/8011377); [Kun.uz 2025](https://kun.uz/en/news/2025/04/16/uzbekistan-takes-steps-to-regulate-ai-with-new-legislation)). Eng muhim ochiq savol: face-swap, "meni videoga qo'y" yoki ovoz klonlash biometrik shablon yaratadimi? Agar yaratsa, bu shablonlar O'zbekistonda saqlanishi va reestrga kiritilishi kerak. Bu advokat uchun birinchi navbatdagi savol.

**Provayder shartlari.** Gemini API Additional Terms quyidagilarni belgilaydi ([Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms)):

- "You must be 18 years of age or older";
- API'ni "likely to be accessed by individuals under the age of 18" bo'lgan ilovada ishlatib bo'lmaydi;
- EEA, CH va UK foydalanuvchilariga faqat Paid Services orqali xizmat ko'rsatiladi;
- bepul tier ma'lumotlari model o'qitishga ishlatiladi.

Bu ilovani 18+ yosh reytingi tomon itaradi; advokat tasdiqlashi kerak. ElevenLabs har qanday tirik shaxs ovozi uchun "explicit and informed consent" talab qiladi, 18 yoshgacha bo'lganlarning ovozini taqiqlaydi va o'z xizmatlariga "client, wrapper, or proxy" orqali xom kirish berishni man etadi ([ElevenLabs Use Policy](https://elevenlabs.io/use-policy)).

## Kod bazasiga ta'siri: o'n ikkita aniq o'zgarish

Quyidagi joylar 14-oktabr 2026 holatidagi repo'da tekshirilgan.

| # | Joy | Hozir | O'zgarish | Asos |
|---|---|---|---|---|
| 1 | `lib/features/ai/ai_clients.dart:307` | `imageModel = 'gpt-image-1'` | `gpt-image-2.5-flare`, tahrir uchun `gpt-image-2.5-sunburst`. `data[0].b64_json` javobini smoke test bilan tasdiqlash | 23-okt shutdown |
| 2 | `ai_clients.dart:316-317` | 9:16 va 4:5 → `1024x1536`, 16:9 → `1536x1024` | 9:16 → `864x1536`, 4:5 → `1024x1280`, 16:9 → `1536x864` | 2.5 custom size qoidalari |
| 3 | `lib/features/director/capability_registry.dart:80` | `note: 'gpt-image-1'` | yangi ID | UI faqat haqiqatni ko'rsatadi |
| 4 | `ai_clients.dart:437`, `:464` | `gemini-2.5-flash-image`, `responseModalities ['TEXT','IMAGE']` | `gemini-nano-banana-2.1` va `['IMAGE']`; keyinroq Interactions API | eskirgan model; 1K cheklovi haqidagi hisobot |
| 5 | `ai_clients.dart:441`, `:504` | `veo-3.1-generate-preview`, faqat `aspectRatio` yuboriladi | ID hali ishlaydi. Davomiylik, resolution va `personGeneration` ni aniq yuborish, Lite va Fast darajalarini qo'shish. 1080p va undan yuqorisi uchun 8 s | Veo hujjati |
| 6 | `server/src/config.ts:33`, `server/src/providers.ts:112` | `gemini-3.1-flash-image`, `['TEXT','IMAGE']` | `gemini-nano-banana-2.1`, `['IMAGE']` | 1K narxi ikki baravar arzon |
| 7 | `server/src/pricing.ts:18` | `IMAGE_CREDITS = 5`, ya'ni $0.05 | Joriy server modeli 1K uchun $0.067 turadi, ya'ni har bir rasm taxminan $0.017 zarar bilan sotiladi. Modelni almashtirish yoki narxni ko'tarish kerak | Gemini pricing |
| 8 | `pubspec.yaml:10` | `ffmpeg_kit_flutter_new_full: ^2.5.7` | Aniq versiyani pin qilish. GPL'li `ffmpeg_kit_flutter_new` ga hech qachon o'tmaslik. CI'da `render_plan.dart` uchun GPL filtr grep'i. 2.5.7 da 16 KB tekislashni tekshirish | litsenziya; 1-fev 2027 |
| 9 | `lib/features/render/render_service.dart:85`, `render_plan.dart:283` | HW H.264 enkoder, ichki `aac` | HW enkoder qoladi, `libopenh264`/`libx264` ga fallback taqiqlanadi. iOS'da `aac_at` ni sinash. Ikki bosqichli `loudnorm` va aniq sample rate | patent va loudness |
| 10 | `lib/app/app_controller.dart:199-200`, `lib/features/chat/chat_screen.dart:335` | faqat `consent_gemini`, qaytarib olib bo'lmaydi | Har bir provayder uchun nomlangan rozilik va sozlamalarda bekor qilish | Apple 5.1.2(i), 5.1.1 |
| 11 | AI natija ekranlari | shikoyat tugmasi yo'q | "Xabar berish" tugmasi → server navbati | Play AI-Generated Content |
| 12 | `docs/HOOKKADR_BLUEPRINT.md`: 78, 351–362, 622 | `gpt-image-1`, `gemini-2.5-flash-image`, OpenAI video "tekshirish kerak" | Yangi ID'lar; Sora yopilgani; ElevenLabs uchun faqat v3/v4 | hujjat haqiqatga mos bo'lishi kerak |

Ikki joy bu tadqiqot doirasidan tashqarida qoldi. Matn modellari — `ai_clients.dart:258` dagi `gpt-5` va `:355` dagi `gemini-2.5-flash` — bu yozuvlarda tekshirilmagan. Ularni OpenAI va Gemini deprecations sahifalari bo'yicha alohida tekshirish kerak.

**Asosiy arxitektura xulosasi.** BYOK rejimida model ID'lari Dart konstantasi bo'lib turar ekan, provayder modelni o'chirganda tuzatishni App Store va Play review'idan o'tkazish kerak bo'ladi. `gpt-image-1` misoli shuni ko'rsatadi: e'londan o'chirishgacha olti oy bor edi, lekin kod baribir eskirgan bo'lib qoldi. Shuning uchun ID'lar server konfiguratsiyasidan yoki remote config'dan kelishi, `capability_registry` esa serverdagi ro'yxatdan qurilishi kerak.

Master prompt quyidagi o'zgarmas qoidalarni qat'iy yozishi kerak:

- model ID'lari faqat server config'da saqlanadi va har biri deprecations sahifasiga havola bilan qo'yiladi;
- har bir provider natijasi darhol serverga yuklab olinadi va qayta joylanadi;
- FFmpeg faqat LGPL `_full` build bilan ishlaydi; GPL filtrlar, `libopenh264` va `libx264` taqiqlanadi;
- mahsulot va logotip piksellari AI'dan emas, `overlay` dan keladi;
- o'zbekcha subtitr faqat Scribe v2 yoki Azure `uz-UZ` dan olinadi, matn esa U+02BB normalizatsiyasidan o'tadi;
- har bir AI chaqiruvidan oldin nomlangan provayder roziligi so'raladi;
- har bir AI natijasida shikoyat tugmasi bo'ladi;
- har bir eksport serverda C2PA bilan imzolanadi;
- Sora, Imagen va `gpt-image-1*` hech qayerda tilga olinmaydi.

## Xulosa

Tadqiqot muhim bir narsani ko'rsatdi: HOOKKADR'ning eng beqaror qatlami AI provayderlari ekan, eng barqaror qatlami esa uning o'z deterministik render dvigateli. Olti oy ichida OpenAI Sora'ni yopdi va `gpt-image-1` ni yopishni e'lon qildi. Google esa Imagen'ni yopdi va ikki marta yangi rasm modelini GA qildi: 3.1 Flash va 3 Pro may oyida, Nano Banana 2.1 oktabrda. FFmpeg filter graph'i va `overlay` asosidagi kompozitsiya esa o'zgarmadi. CLAUDE.md'dagi "AI faqat `EditPlan` yozadi" qoidasi dastlab arxitektura tanlovi edi. Endi u bir vaqtning o'zida sifat, huquq va halollik kafolatiga aylandi: mahsulot naqshi piksel darajasida saqlanadi, o'zbekcha matn `drawtext` orqali to'g'ri chiqadi, C2PA esa FFmpeg'dan keyin bir marta qo'yiladi. Demak investitsiya provayderlar sonini ko'paytirishga emas, server adapter qatlamiga (job jadvali, saqlash, config'dagi ID'lar, narx jadvali) va `RenderGraph` IR'ga yo'naltirilishi kerak.

Ikkinchi xulosa: bir-biriga bog'liq bo'lmagandek ko'ringan huquqiy talablar bitta quyi tizimga birlashadi. Apple 5.1.2(i), O'zbekiston 15-moddasidagi transchegaraviy rozilik, ElevenLabs'ning ovoz roziligi va EU 50(4) oshkor qilish talabini bitta mexanizm qoplaydi. Bu mexanizm uch qismdan iborat: har bir provayder uchun alohida rozilik reestri, server tomonda C2PA imzosi va eksportdagi "AI yordamida yaratilgan" belgisi. Hal qilinmagan uchta savol esa funksiya darajasidagi qarorlarni belgilaydi:

- yuz va ovoz shablonlari O'zbekiston qonunchiligida biometrik ma'lumot hisoblanadimi;
- LGPLv3 App Store bilan qanday mos keladi;
- Gemini'ning 18+ sharti o'zbek yoshlar auditoriyasiga qanday ta'sir qiladi.

Advokat javob bermaguncha face-swap va boshqa shaxs ovozini klonlash funksiyalarini umuman chiqarmaslik eng arzon va eng halol yo'l.
