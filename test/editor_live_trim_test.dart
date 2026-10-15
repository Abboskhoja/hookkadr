// Live ripple trim on the real editor: what the timeline shows WHILE the
// finger is down, what is saved on release, and what happens on cancel.
// (The trim arithmetic itself is covered by ripple_trim_test.dart.)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/editor/editor_screen.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pps = 64.0; // the editor's default zoom, px per second

Map<String, dynamic> _plan() => {
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
  'captions': [
    {'startSec': 5.0, 'endSec': 7.0, 'text': 'ikkinchi kadr'},
  ],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': 30},
};

Future<(AppController, String)> _open(
  WidgetTester tester, {
  List<ProjectClip> clips = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final app = AppController(
    keys: MemoryKeyStore(),
    prefs: await SharedPreferences.getInstance(),
  );
  final project = await app.addProject(_plan(), clips: clips);
  tester.view.physicalSize = const Size(2400, 2532);
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
  return (app, project.id);
}

EditPlan _saved(AppController app, String id) =>
    EditPlan.fromJson(app.byId(id)!.planJson);

double _x(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dx;

void main() {
  testWidgets('the next shot moves with the finger, before anything is saved', (
    tester,
  ) async {
    final (app, id) = await _open(tester);
    final s2Before = _x(tester, 'seg-s2');

    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('trim-right-s1'))),
    );
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(_pps / 8, 0));
      await tester.pump();
    }

    // Live: s2 already sits ~1 s further right on screen...
    expect(_x(tester, 'seg-s2') - s2Before, closeTo(_pps, 4));
    // ...the readout shows the length that will be saved...
    expect(find.text('5 s'), findsWidgets);
    // ...but nothing is persisted until the finger lifts.
    expect(_saved(app, id).shots[0].duration, 4.0);

    await g.up();
    await tester.pumpAndSettle();
    final saved = _saved(app, id);
    expect(saved.shots[0].duration, closeTo(5.0, 0.01));
    expect(saved.shots[1].startSec, closeTo(5.0, 0.01));
    // The caption on s2 moved with it.
    expect(saved.captions.single.startSec, closeTo(6.0, 0.01));

    // One drag = one undo step, however many moves it had.
    await tester.tap(find.byTooltip('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(_saved(app, id).shots[0].duration, 4.0);
    expect(_saved(app, id).captions.single.startSec, 5.0);
  });

  testWidgets('a cancelled gesture saves nothing and snaps back', (
    tester,
  ) async {
    final (app, id) = await _open(tester);
    final s2Before = _x(tester, 'seg-s2');

    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('trim-right-s1'))),
    );
    await g.moveBy(const Offset(_pps, 0));
    await tester.pump();
    expect(_x(tester, 'seg-s2'), greaterThan(s2Before + 30));

    await g.cancel();
    await tester.pumpAndSettle();
    expect(_x(tester, 'seg-s2'), closeTo(s2Before, 0.5));
    expect(_saved(app, id).shots[0].duration, 4.0);
    expect(find.byTooltip('Bekor qilish'), findsOneWidget);
  });

  testWidgets('a shot cannot be stretched past its source clip', (
    tester,
  ) async {
    // clip_01 is 4.5 s long; s1 already uses 0–4 s of it.
    final (app, id) = await _open(
      tester,
      clips: const [
        ProjectClip(id: 'clip_01', path: '/a.mp4', name: 'a', durationSec: 4.5),
      ],
    );
    await tester.drag(
      find.byKey(const ValueKey('trim-right-s1')),
      const Offset(_pps * 3, 0),
    );
    await tester.pumpAndSettle();
    final s1 = _saved(app, id).shots[0];
    expect(s1.duration, closeTo(4.5, 0.01));
    expect(s1.sourceOut, closeTo(4.5, 0.01));
  });

  testWidgets('the edge snaps to the playhead with a haptic tick', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final (app, id) = await _open(tester);

    // Put the playhead at 5.0 s by tapping the ruler there.
    final ruler = tester.getTopLeft(find.byKey(const ValueKey('seg-s1')));
    await tester.tapAt(Offset(ruler.dx + 5 * _pps, ruler.dy - 10));
    await tester.pump();

    // Drag s1's end to ~4.9 s: within the snap window of the playhead.
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('trim-right-s1'))),
    );
    for (var i = 0; i < 6; i++) {
      await g.moveBy(Offset(0.9 * _pps / 6, 0));
      await tester.pump();
    }
    expect(find.byIcon(LucideIcons.magnet), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
    await g.up();
    await tester.pumpAndSettle();
    expect(_saved(app, id).shots[0].endSec, closeTo(5.0, 0.01));
  });
}
