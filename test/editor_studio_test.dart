import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/editor/editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('select a shot, open Effects, pick crossfade and 2x', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      keys: MemoryKeyStore(),
      prefs: await SharedPreferences.getInstance(),
    );
    final project = await app.addProject({
      'schemaVersion': 1,
      'title': 'Studio',
      'summary': 's',
      'durationSec': 8.0,
      'aspectRatio': '9:16',
      'shots': [
        {'id': 's1', 'startSec': 0.0, 'endSec': 4.0, 'description': 'a'},
        {'id': 's2', 'startSec': 4.0, 'endSec': 8.0, 'description': 'b'},
      ],
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': <Map<String, dynamic>>[],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': '1080p', 'fps': 30},
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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

    for (final tip in [
      'Matn qo‘shish',
      'Musiqa',
      'Ritmga moslash',
      'Materiallar',
    ]) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
    }

    // select the second shot on the timeline
    await tester.tap(find.text('2').last);
    await tester.pump();
    await tester.tap(find.byTooltip('Effekt: o‘tish, tezlik, harakat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crossfade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2×'));
    await tester.pumpAndSettle();

    final shots = EditPlan.fromJson(app.byId(project.id)!.planJson).shots;
    expect(shots[1].transition, ShotTransition.crossfade);
    expect(shots[1].speed, 2.0);
    expect(shots[1].duration, 2.0); // 2x halves the shot
    expect(app.byId(project.id)!.history, hasLength(2)); // each step undoable
  });
}
