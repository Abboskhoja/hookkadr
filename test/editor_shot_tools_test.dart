// The transport's own Undo/Redo icon buttons (top of the editor) are a
// separate mechanism from Kadr AI's "bekor qil" command: they walk a local
// undo/redo stack built on every PlanOps change applied through the shot
// tools (split/duplicate/move/trim/freeze). Until now nothing exercised that
// path end-to-end through the real widgets, only through the AI command
// panel. This locks it down, and with it the ShotToolsBar/EditorTimeline/
// DurationStepper extraction done when editor_screen.dart was split up.
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
  // Wide enough that every shot-tool button (7 × 70 px) is on screen at
  // once, so taps don't depend on scrolling a horizontal ListView first.
  tester.view.physicalSize = const Size(2400, 2532);
  tester.view.devicePixelRatio = 3;
  tester.testTextInput.register();
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

Map<String, dynamic> _threeShotPlan() => {
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
      },
  ],
  'mediaSlots': <Map<String, dynamic>>[],
  'captions': <Map<String, dynamic>>[],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': 30},
};

void main() {
  testWidgets('duplicate via the shot tools, then undo and redo it', (
    tester,
  ) async {
    final app = await _appWith(tester, _threeShotPlan());
    final id = app.projects.first.id;

    // Select the second shot: its index label is built after the ruler's
    // own tick labels, so `.last` is the shot segment, as in editor_studio_test.
    await tester.tap(find.text('2').last);
    await tester.pump();

    await tester.ensureVisible(find.text('Nusxa'));
    await tester.tap(find.text('Nusxa'));
    await tester.pumpAndSettle();

    var shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots, hasLength(4));
    expect(shots[1].id, 's2');
    expect(shots[2].id, isNot('s3')); // the duplicate got a fresh id
    expect(shots.map((s) => s.startSec), [0.0, 4.0, 8.0, 12.0]);

    // The transport's own Undo icon reverts the duplicate...
    await tester.tap(find.byTooltip('Bekor qilish'));
    await tester.pumpAndSettle();
    shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots, hasLength(3));
    expect(shots.map((s) => s.id), ['s1', 's2', 's3']);

    // ...and Redo brings it back exactly as it was.
    await tester.tap(find.byTooltip('Qaytarish'));
    await tester.pumpAndSettle();
    shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots, hasLength(4));
    expect(shots[1].id, 's2');
  });

  testWidgets('move left/right reorders the ripple timeline, undoably', (
    tester,
  ) async {
    final app = await _appWith(tester, _threeShotPlan());
    final id = app.projects.first.id;

    await tester.tap(find.text('2').last);
    await tester.pump();

    await tester.ensureVisible(find.text('Chapga'));
    await tester.tap(find.text('Chapga'));
    await tester.pumpAndSettle();

    var shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    // s2 swapped with s1: order is now s2, s1, s3, still gap-free.
    expect(shots.map((s) => s.id), ['s2', 's1', 's3']);
    expect(shots.map((s) => s.startSec), [0.0, 4.0, 8.0]);
    expect(shots.last.endSec, 12.0);

    await tester.tap(find.byTooltip('Bekor qilish'));
    await tester.pumpAndSettle();
    shots = EditPlan.fromJson(app.byId(id)!.planJson).shots;
    expect(shots.map((s) => s.id), ['s1', 's2', 's3']);
  });
}
