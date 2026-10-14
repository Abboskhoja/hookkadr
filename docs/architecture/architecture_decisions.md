# Architecture decisions (ADR)

1. **AI qaror qiladi, deterministik engine bajaradi.** AI faqat `EditPlan` (yoki qat'iy JSON buyruq) yozadi;
   render `render_plan.dart` orqali. Model matni hech qachon to'g'ridan-to'g'ri fayl amaliga aylanmaydi.
2. **Kadr AI — o'z runtime'imiz.** llama.cpp (MIT, pin qilingan b11429) + C qatlami + Dart FFI. Tayyor Flutter
   paketlari rad etildi: `llm_llamacpp` iOS binary buzuq, `fllama` eski (Gemma 4'ni tanimaydi).
3. **Model o'lchov bilan tanlanadi** (`ai/hookkadr_ai/llm/bench.py`). Gemma 4 E2B: o'zbekcha izchil; Qwen3.5
   0.8B/2B yaroqsiz o'zbekcha. Kichik model formatga amal qilmasa — GBNF grammatika bilan majburlanadi.
4. **`lib/src/` ga ko'chirish hozir qilinmaydi.** 61 faylni ko'chirish xatti-harakatni o'zgartirmaydi, lekin
   parallel ishlayotgan agentlar bilan to'qnashuv beradi. Yangi feature'lar `domain/application/presentation`
   bo'linmasi bilan yoziladi (masalan `product_ad`); mavjudlari tegilganda bosqichma-bosqich ko'chadi.
5. **State management**: hozircha ChangeNotifier. Riverpod — ekranlar soni ortganda, alohida bosqich.
6. **Vaqt**: `EditPlan` v1 soniyada (double). Yangi kompozitorlar ichida kadr (frame) bo'yicha hisoblanib,
   soniyaga aylantiriladi; v2 kadr-asosli shartnoma — rejada.
7. **Musiqa**: litsenziyasi noaniq trek ilovaga qo'shilmaydi. Kadr AI fon musiqasi FFmpeg bilan sintez qilinadi
   (o'zimizniki), yoki foydalanuvchi o'z faylini tanlaydi.
