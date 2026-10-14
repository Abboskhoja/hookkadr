# Dependency map

- UI (`lib/features/*/presentation`, ekranlar) → `AppController` (state) → domain/servislar.
- `chat_screen` → `PlanGenerator` (TextModel) → `EditPlan` → `RenderService` → `render_plan` (FFmpeg).
- `TextModel` implementatsiyalari: `KadrLocalModel` (telefonda, `kadr_llm`), Claude/OpenAI/Gemini/OpenRouter
  (BYOK, Pro), `HookkadrCloudClient` (server). Router: telefondagi Kadr AI birinchi.
- `MediaAnalyzer` (FFmpeg) → `ClipFacts` → `AutoEditor` / `QualityControl` / `KadrDirector`.
- Paketlar: ffmpeg_kit_flutter_new_full (render), video_player (preview), image_picker/file_picker (import),
  gal (galereya), flutter_secure_storage (kalitlar), shared_preferences (loyihalar), http, crypto (sha256),
  kadr_llm (o'z runtime), google_fonts/lucide/flutter_animate (UI).
