# HOOKKADR — AI agentlar uchun qisqa yo'riqnoma

To'liq hujjat: `docs/HOOKKADR_BLUEPRINT.md` (mahsulot, dizayn tokenlari, arxitektura, holat).

- Flutter/Dart, iOS 16+ va Android minSdk 30. Tekshiruv: `flutter analyze` (0 muammo),
  `flutter test`, `flutter build ios --simulator --debug --no-codesign`.
- Integration testlar simulyatorda: `flutter test integration_test/<file> -d <device>`.
- Ranglar faqat `AppPalette` (`lib/core/theme/app_theme.dart`), ikonkalar faqat `LucideIcons`.
- AI faqat `EditPlan` yozadi; video `lib/features/render/render_plan.dart` orqali FFmpeg'da yig'iladi.
- API kalitlari kodda bo'lmaydi; ishlamaydigan funksiyani ishlayotgandek ko'rsatma.
- Foydalanuvchiga ko'rinadigan matnlar o'zbekcha (lotin).
- Palitra manbasi: `lib/core/theme/app_theme.dart` (ko'k + och jigarrang, krem fon; och mavzu asosiy, video muharriri to'q). Boshqa vosita bilan bir vaqtda tahrirlama.
- Kadr AI modellari: foydalanuvchi o'rnatmaydi — ilova ichida (`tool/bundle_kadr_models.sh`) yoki birinchi ishga tushishda avtomatik (Wi-Fi).
- Server: `server/` (Node 26 TS). `cd server && npm test`; dev: `DEV_AUTH=1 PROVIDERS=fake PORT=8787 npm start`. AI kalitlari faqat serverda.
