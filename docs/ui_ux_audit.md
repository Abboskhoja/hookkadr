# HOOKKADR — UI/UX audit (2026-10-15)

Honest snapshot of the real app, not a generic checklist. Every item below was
checked against the current code in this session (file/line where it
matters), not assumed. Severity: **Critical** = a flow is unusable, **High**
= a real UX problem a user will hit, **Medium** = a visible but non-blocking
issue, **Low** = polish.

**Palette note:** a pasted spec proposed a dark "Premium Cinematic" palette
(`#080D14` app background, `#1673B8`/`#FF9950` accents) as the app-wide
default. That contradicts the user's own repeated, explicit decision (and
`CLAUDE.md`'s checked-in rule): light theme by default, blue + light-brown on
cream, only the editor stays dark. This audit keeps that decision and does
not treat "the app isn't dark-themed" as a finding.

## What's already real (not just planned)

Worth stating plainly, since a lot of this prompt's own Phase 0–3 targets are
already done, not theoretical:

- Centralized design tokens: `lib/core/theme/app_theme.dart` (`AppPalette`,
  `AppColors`, `AppText`) — no screen hardcodes a color outside it except the
  editor's intentionally-separate dark timeline canvas.
- No app bars anywhere: `GlassPage`/`PageHeader` (`lib/core/widgets/common.dart`)
  — title scrolls with content, only tappable controls float, as Liquid Glass.
- A real bottom nav (`LiquidGlassTabBar.withImpeller` in `home_shell.dart`),
  verified rendering correctly on a physical Android phone, not just a
  simulator.
- A real `EditPlan`/`PlanOps`/`render_plan.dart` pipeline: split, trim, move,
  duplicate, freeze-frame, speed, transitions, color grade, music ducking,
  beat-sync — all real FFmpeg output, not mocked, each covered by
  `test/studio_ops_test.dart`.
- Direct-manipulation timeline (added this session): drag trim handles and
  long-press reorder on `EditorTimeline`, committing through the same
  `PlanOps` + undo/redo path the toolbar buttons use, covered by
  `test/editor_timeline_drag_test.dart`.
- Kadr AI runs on-device (`packages/kadr_llm`, `packages/kadr_diffusion`):
  chat, image generation, AnimateDiff video — verified launching on a real
  Android phone this session, not just claimed.

## Confirmed by real interaction, not just navigation

`integration_test/mobile_flows_test.dart` (run:
`flutter test integration_test/mobile_flows_test.dart -d <device>`) types and
sends in each chat mode and found a real crash this audit's static read-through
missed: `_EmptyHome`'s `ConstrainedBox(minHeight: box.maxHeight - 24)`
(`chat_screen.dart:1690`) went negative — and threw — whenever the keyboard
left less than 24px of room, i.e. the first time anyone actually typed into
Kadr AI on a modest-height screen. Fixed (clamped to 0) and now covered by
that test. This is the strongest evidence in this audit for why "add a test
that just navigates" and "add a test that actually uses the screen" are
different bars. It also means the editor findings below (read from code, not
yet driven this way) deserve the same real-interaction pass before being
called done.

## Per-screen findings

### Home (`lib/features/home/home_screen.dart`)
- **Medium** — no first-run explainer. `AppController.onboardingDone` /
  `markOnboardingDone()` exist (`lib/app/app_controller.dart:506-507`) but
  nothing in `lib/` ever calls `markOnboardingDone()` or branches on
  `onboardingDone` to show an explainer screen — it's dead scaffolding. Tests
  only reach Home by pre-seeding the flag. A new user gets no "what is this
  app, why does it need media access" screen before landing on the hero
  input.
- **Low** — project cards' "last edited" / duration come straight from real
  project data (no fabricated demo content), so the master-prompt's "don't
  show fake projects" risk doesn't apply here; confirmed, not a finding.

### AI Studiya / chat (`lib/features/chat/chat_screen.dart`, 3217 lines)
- **Medium** — one file carries the whole chat screen: composer, format
  sheet, model picker, message rendering, montage flow, image/video
  generation wiring. Not broken, but the same "single giant file" shape the
  editor had before this session's refactor — a future change here risks the
  same class of bug (widget-identity loss mid-gesture) the editor refactor
  explicitly had to fix twice.
- **Low** — AI capability states exist and are honest (`needsAi`,
  `offlineInstalled`, setup banner with real progress), matching the
  "never claim a model that isn't there" rule this project already follows.

### Loyihalar / Shablonlar / Profil
- **Low** — consistent `GlassPage` usage, empty states use real
  `EmptyState`, no demo data. No findings beyond what's already tracked in
  `docs/architecture/current_limitations.md`.

### Video editor (`lib/features/editor/`)
- **High** — no granular rebuild during playback. `_togglePlay`'s 40ms timer
  calls `setState` on the whole `_buildEditor` tree (preview + timeline +
  inspector + toolbar) every tick — flagged by this session's own refactor
  pass, not yet fixed. On a slow device this is the one place "professional
  editor" framing and actual frame pacing can visibly diverge.
- **Medium** — single video track. `EditPlan` has no `tracks[]` concept, so
  there's no overlay/PiP/second-video-track layer — a real gap against
  "professional," already on the backlog from the editor audit, not new.
  Out of scope for a quick fix: this is a schema change (`EditPlan`,
  `render_plan.dart`, the timeline UI) that deserves its own planned phase,
  not a drive-by patch.
- ~~**Medium** — trim is commit-on-release, not live-ripple.~~ **Fixed
  2026-10-15:** live ripple trim (`RippleTrim`), frame-accurate, source-limited,
  snapping to playhead/beats, captions anchored; see the blueprint changelog.
  Still open: the trim handle's touch area is 16 px wide (visual and hit
  area are the same) — below the 44/48 pt guideline on narrow shots.
- **Low** — reorder has no neighbor-slides-live animation; drop snaps to
  nearest clip center. Visual polish gap, not a functional one.

## Cross-cutting

- **High — no accessibility coverage.** `Semantics`/`semanticLabel` appear in
  only 2 files across all of `lib/features` + `lib/core/widgets`
  (`GlassIconButton`/`PageHeader` in `common.dart`, and the home screen's
  quick-action cards / AI status chip).
  No contrast, hit-target, or screen-reader test exists anywhere in `test/`.
  For an app this far along, this is the single most concrete, checkable gap
  the pasted spec's Section 23 calls out, and it's real.
- **High — no visual regression (golden) tests.** Every "golden" match in
  `test/` is an unrelated JSON fixture comparison (`scene_quality_golden.json`
  naming), not a Flutter `matchesGoldenFile` test. A screen can visibly
  regress (overflow, color drift, broken layout) and the test suite would
  stay green.
- **Medium — no adaptive/tablet layout.** No breakpoint logic (`LayoutBuilder`,
  width-based `600`/`840` splits) exists outside the home quick-actions grid's
  2-vs-4-column switch. A tablet gets the phone layout stretched, not a
  deliberately wider editor/inspector layout.
- **Medium — permission requests have no in-app rationale.** Camera
  (`ImagePicker.pickVideo(source: camera)`), gallery (`image_picker`,
  `gal`), and file access trigger the bare OS dialog with no HOOKKADR-authored
  explanation first. Flagged last turn, still open.
- **Low — state management is a single `ChangeNotifier`**
  (`AppController`, 500+ lines, `lib/app/app_controller.dart`). Works, is
  tested, and a BLoC/Cubit migration would be a large, independent
  architecture project with its own risk — not something to do opportunistically
  alongside UI work. Noting it as a deliberate "not now," not an oversight.

## Priority summary (what would move the needle most, in order)

1. **Accessibility pass** — add `Semantics`/labels to the interactive
   surfaces that lack them (editor toolbar icons, timeline handles, quick
   action cards) and a handful of contrast/hit-target tests. Bounded, real,
   checkable.
2. **Onboarding screen** — wire the already-modeled `onboardingDone` flag to
   an actual first-run explainer (what the app does, that it's offline-first,
   why media access is asked for) before Home.
3. **Permission rationale UX** — a short in-app explanation before the OS
   camera/gallery dialogs.
4. **Playback performance** — scope the granular-rebuild fix for the editor's
   play loop (carried over from the editor refactor's own findings).
5. **Golden tests** for Home, Editor, AI Studiya, Settings at 2–3 screen
   sizes — catches visual regressions the current suite can't see.
6. **Multi-track `EditPlan`** — the real "professional" ceiling (overlay/PiP
   track), but it's a schema-and-render-pipeline project of its own, not a
   patch; plan it separately rather than starting it opportunistically.

Each of 1–5 is independently small enough to do in one focused pass; 6 is not
and shouldn't be started without its own scoping pass first.
