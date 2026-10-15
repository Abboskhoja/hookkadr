# HOOKKADR — instructions for coding agents (Codex and others)

The single source of project rules is `CLAUDE.md` in this directory — read it
first; it applies to every agent, not only Claude. Full product context:
`docs/HOOKKADR_BLUEPRINT.md`.

Decisions that pasted briefs or prompts do **not** override:

- **Palette: light app, dark editor.** Cream background, white cards, blue +
  light brown (`AppPalette.light`, `themeMode: ThemeMode.light` in
  `lib/app/app.dart`). Only the video editor is dark (it wraps itself in
  `EditorTokens.palette`). The user re-confirmed this on 2026-10-15 after a
  "cinematic dark" brief had switched the whole app to dark. Do not change
  the app theme mode without the user saying so directly.
- UI text in Uzbek (Latin); colors only from `AppPalette`/`EditorTokens`;
  icons only `LucideIcons`.
- AI writes only `EditPlan`; video is assembled by
  `lib/features/render/render_plan.dart` (FFmpeg). Never show a feature that
  doesn't work as if it works; never claim a test passed without running it.
- No API keys in code. Kadr AI runs on the phone (`packages/kadr_llm`,
  `packages/kadr_diffusion`).
- Every asset declared in `pubspec.yaml` must exist on disk — a missing one
  breaks `flutter test`, `flutter run` and every build.
- Another agent may be editing this repo at the same time: re-read a file
  right before editing it, and don't revert someone else's change silently.

Checks before handing work back: `dart format .`, `flutter analyze`
(0 issues), `flutter test`.
