# Current limitations

- Haqiqiy iPhone va Android qurilmalarda sinalmagan (NOT VERIFIED ON DEVICE).
- iPhone build'larida Kadr AI miyasi va rassomi Metal (GPU) bilan, simulyatorda faqat CPU. Haqiqiy iPhone'dagi tezlik o'lchanmagan. Android `.so` yo'q (NDK yo'q).
- Kadr AI 6 GB+ RAM talab qiladi; kichik modellar o'zbekchada yaroqsiz (benchmark).
- Telefonda rasm (DreamShaper 8 LCM, SD 1.5) va video (AnimateDiff-Lightning) bor, lekin sifati SD 1.5 darajasida (448×768 rasm, 320×576 jonli klip, keyin 1080p'ga kattalashtiriladi). Jonli klip 2,7 s, matnli kadr chizolmaydi.
- To'liq Kadr AI uchun ~6,2 GB yuklab olish kerak (miya 3,1 + rassom 2,1 + harakat 0,9 GB); rassom 6 GB, jonli video 8 GB RAM talab qiladi.
- iOS'da katta xotira uchun `com.apple.developer.kernel.increased-memory-limit` entitlement'i hali yoqilmagan (Apple Developer akkaunt sozlamasi kerak).
- "Rivojlanish" = xotira (faktlar, uslub/format afzalliklari, 👍/👎), model og'irliklari o'qitilmaydi.
- O'zbekcha STT yo'q.
- `EditPlan` v1 soniyaga asoslangan (kadr-asosli v2 — rejada); multi-track cheklangan.
- Lokalizatsiya faqat o'zbekcha; router/Riverpod yo'q.
- Kadr AI fon musiqasi — oddiy sintez (I–V–vi–IV, 90 BPM), kompozitor ishi emas; foydalanuvchi o'z musiqasini qo'yishi mumkin.
- Reklama natijasi faqat simulyatorda va sintetik test rasmlarida tekshirilgan; haqiqiy mahsulot fotolarida sifat baholanmagan.
- Barcha Kadr AI modellari ilovaga joylansa ~6,2 GB — App Store 4 GB chegarasidan oshadi; do'kon build'i birinchi ishga tushishda (Wi-Fi) avtomatik tayyorlanadi. Background Assets / Play Asset Delivery hali qilinmagan.

