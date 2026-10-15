# Hookkadr — audit yangilanishi, 2026-10-15

## Muhit va bazaviy dalil

Workspace `/Users/abboskhuja/Flutter/hookkadr`, branch `main`; foydalanuvchining ko‘p saqlanmagan o‘zgarishlari bor. Reset, clean, package upgrade va push bajarilmadi.

Flutter 3.47.7, Dart 3.13.5, Xcode 27.0, Android SDK 36.0.0. `flutter doctor -v`: umumiy diagnostika muammosiz, fizik iPhone wireless discovery code -27 ogohlantirishi bor. Ulangan mobil target — iOS simulator; fizik Android ko‘rinmadi.

`flutter pub deps` bajarildi. Baseline: `flutter analyze` xatosiz; `flutter test` 358 pass, 1 skip. `server/`: `npm run typecheck` va `npm test` muvaffaqiyatli, 12 test. Server testi live provider inference emas.

## Modullar va tasdiqlash chegarasi

| Qism | Dalil | Holat |
|---|---|---|
| Navigatsiya | `lib/features/home/home_shell.dart` | IndexedStack va mavjud Navigator marshrutlari; yangi router talab qilinmaydi |
| Loyiha holati | `lib/app/app_controller.dart`, `features/projects/project.dart` | ChangeNotifier, JSON, history; storage va AI routing bir controller ichida |
| Montaj | `features/plan/plan_ops.dart`, `features/editor/widgets/editor_timeline.dart` | Split/trim/reorder/ripple/undo testlari bor; to‘liq video overlay multitrack emas |
| AI buyruqlar | `features/plan/command_agent.dart`, `features/director/kadr_director.dart` | Deterministik lokal parser va director; generativ model bilan teng emas |
| Tasdiqlash | `features/editor/widgets/kadr_ai_sheet.dart` | Lokal va online takliflar Apply/Cancel orqali; avvalgi auditdagi “lokal darhol qo‘llanadi” xulosasi eskirgan |
| Render | `features/render/render_service.dart`, `render_verification.dart` | FFmpeg hardware encoder va FFprobe tekshiruvi; bu auditda native eksport qayta bajarilmadi |
| Preview | `features/editor/editor_screen.dart` | VideoPlayer, alohida preview render yo‘li; eksport bilan to‘liq parity isbotlanmagan |
| Lokal modellar | `features/kadr_ai/`, `packages/kadr_llm/`, `packages/kadr_diffusion/` | Dart adapter va native runtime; haqiqiy generativ sifat bu auditda tekshirilmagan |
| Online AI | `features/ai/ai_clients.dart`, `openrouter.dart`, `hookkadr_cloud.dart` | Mavjud Anthropic/OpenAI/Gemini/OpenRouter/cloud adapterlar; yangi xizmat ulanmagan |
| Backend | `server/src/app.ts`, `auth.ts`, `credits.ts`, `providers.ts` | TypeScript/Fastify, autentifikatsiya, kreditlar, provider proxy; Dart’ga qayta yozish asoslanmagan |
| Platform entry | `android/.../MainActivity.kt`, `ios/Runner/AppDelegate.swift` | Flutter host va plugin registration; ular o‘zlari custom GPU renderer emas |
| CI | `.github/workflows/flutter_ci.yml` | Format/analyze/test/server va Android/iOS build joblari bor; CI remote holati bu auditda tekshirilmagan |

## Xatarlar va tasnif

- **FIX → tuzatildi:** `AppController.load` yaroqsiz project yozuvlarini tashlab o‘qirdi; keyingi `_persist` ularni yo‘qotardi. `ProjectStore` asl xom JSON’ni alohida recovery arxiviga yozmaguncha almashtirmaydi.
- **KEEP:** mavjud brend, navigatsiya, PlanOps, FFmpeg, provider va native model adapterlar. Starter paketdagi fake analyzer bilan almashtirilmaydi.
- **REFACTOR:** AppController bir necha mas’uliyatni bajaradi. Bu bosqichda faqat project serialization/recovery siyosati ajratildi.
- **FIX nomzodi:** `RenderService.cancel()` global `FFmpegKit.cancel()` chaqiradi; bir necha job bo‘lsa boshqasini ham to‘xtatishi mumkin. Session bo‘yicha cancellation va failure cleanup alohida test talab qiladi.
- **FIX nomzodi:** `ClipImporter` media decode va thumbnail resurslari hamda dublikat importlar alohida audit/test talab qiladi.
- **Performance:** preview va eksport alohida engine; real-device 60 FPS, xotira va thermal natijasi yo‘q. Bular o‘lchanmaguncha kafolat berilmaydi.
- **REMOVE CANDIDATE:** `google_fonts`, `animate_do`, `flutter_ai_toolkit` source importlari topilmadi; foydalanuvchi ularni yaqinda qo‘shishni so‘ragan. O‘chirilmadi. Toolkit transitiv Firebase/camera/audio dependencylarini olib keladi; o‘rnatilgani integratsiya degani emas.
- **Security:** provider keys bu auditda o‘qilmadi. `server/src/config.ts` production’da fake/dev auth’ni rad etadi; `app.ts` upload limit va per-user rate limit qo‘llaydi. To‘liq security penetration testi bajarilmadi.
- **Planned:** RNNoise, ASR sifat o‘lchovi, advanced VFX, training checkpointlari, URL research/SSRF siyosati va to‘liq generativ video acceptance bu testlar bilan tasdiqlanmagan.

## Saqlash tuzatishining chegarasi

`ProjectStore` SharedPreferences adapterini saqlaydi. Bu transactional database yoki fsync kafolati emas. Recovery arxivi lokal JSON nusxalaridan iborat; avtomatik o‘chirilmaydi, asl media ko‘chirilmaydi. Backup buzilgan yoki yozib bo‘lmasa xato qaytadi va project key o‘zgartirilmaydi. Storage muvaffaqiyatsiz bo‘lsa controller’ning optimistik in-memory holatini rollback qilish va UI’da yagona xato banneri keyingi ish.

Recovery arxivi uchun foydalanuvchi ko‘radigan import/export/tiklash oynasi hali yo‘q. Bu o‘zgarish buzilgan JSON’ni tuzatdim degani emas; asl dalilni yo‘qotmasdan saqlaydi.
