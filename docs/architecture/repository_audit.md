# Repository audit — 2026-10-14

| Narsa | Holat |
|---|---|
| Flutter / Dart | 3.47.7 stable / 3.13.5 (macOS arm64, Xcode 27, iOS 27 simulyator) |
| Platformalar | iOS 16+, Android minSdk 30 (Android NDK hozir o'rnatilmagan) |
| Kod | `lib/` 61 Dart fayl (~16.7k qator), feature-first: `lib/features/<feature>/` |
| State | `ChangeNotifier` (`AppController`) + `InheritedNotifier` (`AppScope`); router yo'q (Navigator) |
| Saqlash | SharedPreferences (loyihalar, suhbatlar), Keychain/Keystore (kalitlar), fayllar Documents/AppSupport |
| Media engine | FFmpeg (`ffmpeg_kit_flutter_new_full`, LGPL), `render_plan.dart` — sof funksiya, HW enkoder |
| Kadr AI (telefonda) | `packages/kadr_llm` — o'z llama.cpp runtime'imiz (FFI, isolate), Gemma 4 E2B; iOS xcframework |
| O'z o'qitilgan model | `scene_quality` 1.0.0 (PyTorch MLP, `ai/`), telefonda Dart'da ishlaydi |
| Server | `server/` Fastify TS (kredit, AI proxy) — deploy qilinmagan |
| Testlar | 223 unit/widget case (`test/`), 4 integration (`integration_test/`), Python 38, server 12 |
| Native kod | `ios/Runner` (AppDelegate/SceneDelegate), `android/.../kotlin` — maxsus native media kod yo'q |

Tekshiruv buyruqlari: `flutter analyze`, `flutter test`, `cd ai && uv run pytest`, `cd server && npm test`,
`flutter test integration_test/<file> -d <simulator>`.
