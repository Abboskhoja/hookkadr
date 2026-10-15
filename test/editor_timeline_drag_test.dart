// Direct-manipulation gestures on the timeline (CapCut-style): dragging a
// shot's right edge resizes it, dragging its left edge trims the head, and
// a long-press-drag on its body reorders it. All three go through the exact
// same `PlanOps` calls the button-based ShotToolsBar already uses, and all
// three must be undoable with the transport's own Undo button — this is
// what these tests lock down.
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/editor/editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppController> _appWith(
  WidgetTester tester,
  Map<String, dynamic> plan,
) async {
  SharedPreferences.setMockInitialValues({});
  final app = AppController(
    keys: MemoryKeyStore(),
    prefs: await SharedPreferences.getInstance(),
  );
  final project = await app.addProject(plan);
  // Wide enough that the whole 3-shot timeline (3 × ~253 px at the default
  // 64 px/s zoom) is on screen, so drags don't need prior scrolling.
  tester.view.physicalSize = const Size(2400, 2532);
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(
    AppScope(
      controller: app,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: EditorScreen(projectId: project.id),
      ),
    ),
  );
  await tester.pump();
  return app;
}

/// Three 4 s shots, each backed by a real source clip (`sourceIn`/`sourceOut`
/// set), so a head-trim (which requires `sourceIn`) is actually possible.
Map<String, dynamic> _threeShotPlanWithSource() => {
  'schemaVersion': 1,
  'title': 'Studio',
  'summary': 's',
  'durationSec': 12.0,
  'aspectRatio': '9:16',
  'shots': [
    for (var i = 0; i < 3; i++)
      {
        'id': 's${i + 1}',
        'startSec': i * 4.0,
        'endSec': i * 4.0 + 4,
        'description': 'k${i + 1}',
        'sourceClipId': 'clip_0${i + 1}',
        'sourceIn': 0.0,
        'sourceOut': 4.0,
      },
  ],
  'mediaSlots': <Map<String, dynamic>>[],
  'captions': <Map<String, dynamic>>[],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': 30},
};

void main() {
  testWidgets('dragging the right handle resizes the shot, undoably', (
    tester,
  ) async {
    final app = await _appWith(tester, _threeShotPlanWithSource());
    final id = app.projects.first.id;

    final before = EditPlan.fromJson(app.byId(id)!.planJson).shots[0];
    expect(before.duration, 4.0);

    // Drag s1's right handle 1 second's worth of pixels to the right
    // (default zoom is 64 px/s) to grow the shot.
    await tester.drag(
      find.byKey(const ValueKey('trim-right-s1')),
      const Offset(64, 0),
    );
    await tester.pumpAndSettle();

    var shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots[0].duration, closeTo(5.0, 0.15));
    // Ripple: the rest of the timeline shifted right by the same amount,
    // nothing overlaps and nothing was invented.
    expect(shots[1].startSec, closeTo(before.duration + 1.0, 0.15));

    await tester.tap(find.byTooltip('Bekor qilish'));
    await tester.pumpAndSettle();
    shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots[0].duration, closeTo(4.0, 0.05));
  });

  testWidgets('dragging the left handle trims the head, undoably', (
    tester,
  ) async {
    final app = await _appWith(tester, _threeShotPlanWithSource());
    final id = app.projects.first.id;

    // Drag s2's left handle right by half a second's worth of pixels: that
    // removes footage from the head, so the shot gets shorter.
    await tester.drag(
      find.byKey(const ValueKey('trim-left-s2')),
      const Offset(32, 0),
    );
    await tester.pumpAndSettle();

    var shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    final trimmed = shots.firstWhere((s) => s.id == 's2');
    expect(trimmed.duration, closeTo(3.5, 0.15));
    expect(trimmed.sourceIn, closeTo(0.5, 0.15));

    await tester.tap(find.byTooltip('Bekor qilish'));
    await tester.pumpAndSettle();
    shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots.firstWhere((s) => s.id == 's2').duration, closeTo(4.0, 0.05));
  });

  testWidgets('long-press-drag reorders a shot, undoably', (tester) async {
    final app = await _appWith(tester, _threeShotPlanWithSource());
    final id = app.projects.first.id;

    expect(EditPlan.fromJson(app.byId(id)!.planJson).shots.map((s) => s.id), [
      's1',
      's2',
      's3',
    ]);

    // Long-press s1's body, then drag it past s3's centre and drop it —
    // the ripple timeline reorders to s2, s3, s1.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('shot-s1'))),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(600, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    var shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots.map((s) => s.id), ['s2', 's3', 's1']);
    // Still a gap-free, in-order ripple timeline.
    expect(shots[0].startSec, 0.0);
    expect(shots.last.endSec, 12.0);

    await tester.tap(find.byTooltip('Bekor qilish'));
    await tester.pumpAndSettle();
    shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots.map((s) => s.id), ['s1', 's2', 's3']);
  });
}
