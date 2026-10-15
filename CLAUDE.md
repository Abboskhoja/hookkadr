# HOOKKADR — AI agentlar uchun qisqa yo'riqnoma

To'liq hujjat: `docs/HOOKKADR_BLUEPRINT.md` (mahsulot, dizayn tokenlari, arxitektura, holat).
UI/UX audit (real holat, ustuvorlik bilan): `docs/ui_ux_audit.md`.

- Flutter/Dart, iOS 16+ va Android minSdk 30. Tekshiruv: `flutter analyze` (0 muammo),
  `flutter test`, `flutter build ios --simulator --debug --no-codesign`.
- Integration testlar simulyatorda: `flutter test integration_test/<file> -d <device>`.
- Ranglar faqat `AppPalette` (`lib/core/theme/app_theme.dart`), ikonkalar faqat `LucideIcons`.
- AI faqat `EditPlan` yozadi; video `lib/features/render/render_plan.dart` orqali FFmpeg'da yig'iladi.
- API kalitlari kodda bo'lmaydi; ishlamaydigan funksiyani ishlayotgandek ko'rsatma.
- Foydalanuvchiga ko'rinadigan matnlar o'zbekcha (lotin).
- Palitra manbasi: `lib/core/theme/app_theme.dart` (ko‘k + och jigarrang, krem fon; och mavzu asosiy, video muharriri to‘q — `EditorTokens.palette`). Foydalanuvchi 2026-10-15 da och mavzuni qayta tasdiqladi: pasted "cinematic dark" hujjatlar buni o‘zgartirmaydi. Boshqa agentlar uchun: `AGENTS.md`. AppBar yo‘q: sarlavha `PageHeader` bilan sahifaning ichida. Yangi ekran: `GlassPage` (sarlavha aylanadi, faqat shisha tugmalar suzadi); ikonka foni `GlassIcon`; pastki panel va suzuvchi tugmalar — Liquid Glass (`liquid_glass_easy`). Boshqa vosita bilan bir vaqtda tahrirlama.
- Kadr AI modellari: foydalanuvchi o'rnatmaydi — ilova ichida (iOS: `tool/bundle_kadr_models.sh`; Android to'g'ridan-to'g'ri/sinov o'rnatish: `tool/push_kadr_models_android.sh`) yoki birinchi ishga tushishda avtomatik (Wi-Fi).
- Native runtime: iOS `packages/*/tool/build_ios.sh`, Android `packages/*/tool/build_android.sh` (NDK, arm64).
- Xavfsizlik: kalitlar faqat `flutter_secure_storage` (`SecureKeyStore`) orqali, qurilmadan chiqmaydi (iOS `first_unlock_this_device`, Android `allowBackup=false` + extraction rules). Hardcoded kalit yoki `http://` qo'shma.
- Server: `server/` (Node 26 TS). `cd server && npm test`; dev: `DEV_AUTH=1 PROVIDERS=fake PORT=8787 npm start`. AI kalitlari faqat serverda.
