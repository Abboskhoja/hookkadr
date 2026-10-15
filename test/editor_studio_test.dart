import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/director/kart_production.dart';
import 'package:hookkadr/features/editor/editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('KART storyboard is persisted, reviewable and undoable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      keys: MemoryKeyStore(),
      prefs: await SharedPreferences.getInstance(),
    );
    final initial = KartProduction.build(
      request: '10 soniyalik reklama yarat',
      title: 'Mahsulot',
    ).plan..remove('production');
    final project = await app.addProject(initial);
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
    await tester.tap(find.textContaining('Kadr AI’ga ayting'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Reklama storyboardini tuz',
    );
    await tester.tap(find.text('Bajarish'));
    await tester.pumpAndSettle();
    expect(find.text('AI montajchi taklifi'), findsOneWidget);
    await tester.tap(find.text('Qo‘llash'));
    await tester.pumpAndSettle();
    expect(
      app.byId(project.id)!.planJson['production']['schema'],
      'kart.production/1',
    );
    expect(app.byId(project.id)!.history, hasLength(1));
    expect(find.text('Storyboard · 5 kadr'), findsOneWidget);
    await tester.ensureVisible(find.text('Storyboard · 5 kadr'));
    await tester.tap(find.text('Storyboard · 5 kadr'));
    await tester.pumpAndSettle();
    expect(find.text('Storyboard JSON nusxalash'), findsOneWidget);
    await tester.tap(find.text('Storyboard · 5 kadr'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'bekor qil');
    await tester.ensureVisible(find.text('Bajarish'));
    await tester.tap(find.text('Bajarish'));
    await tester.pumpAndSettle();
    expect(app.byId(project.id)!.planJson.containsKey('production'), isFalse);
    expect(find.text('Storyboard · 5 kadr'), findsNothing);
  });

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

    // Every tool is named on screen, not hidden in a tooltip.
    for (final name in ['Qo‘shish', 'Matn', 'Musiqa', 'Rang', 'Ritm']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }

    // select the second shot on the timeline
    await tester.tap(find.text('2').last);
    await tester.pump();
    await tester.tap(find.text('Effekt'));
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

  testWidgets('KART AI panel executes a command, reports it and undoes it', (
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

    await tester.tap(find.textContaining('Kadr AI’ga ayting'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Videoni 6 soniyaga qisqartir va kino uslubini ber',
    );
    await tester.tap(find.text('Bajarish'));
    await tester.pumpAndSettle();

    expect(find.text('AI montajchi taklifi'), findsOneWidget);
    await tester.tap(find.text('Qo‘llash'));
    await tester.pumpAndSettle();
    var plan = EditPlan.fromJson(app.byId(project.id)!.planJson);
    expect(plan.durationSec, closeTo(6, 0.2));
    expect(plan.grade, isNotNull);
    expect(find.textContaining('qisqartirildi'), findsOneWidget);
    expect(find.textContaining('kino'), findsWidgets);

    // Understood nothing and no AI connected: honest message, no change.
    await tester.enterText(find.byType(TextField).last, 'asdf qwerty');
    await tester.tap(find.text('Bajarish'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tushunmadim'), findsOneWidget);
    plan = EditPlan.fromJson(app.byId(project.id)!.planJson);
    expect(plan.durationSec, closeTo(6, 0.2));

    // Undo restores the plan before the last applied command (the grade),
    // so the grade is gone but the shortened timeline remains...
    await tester.enterText(find.byType(TextField).last, 'bekor qil');
    await tester.tap(find.text('Bajarish'));
    await tester.pumpAndSettle();
    plan = EditPlan.fromJson(app.byId(project.id)!.planJson);
    expect(find.textContaining('bekor qilindi'), findsOneWidget);
    // ...one message applied both changes, so one undo reverts both.
    expect(plan.durationSec, closeTo(12, 0.2));
    expect(plan.grade, isNull);
  });

  testWidgets('KART AI reviews quality and offers a one-tap fix', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      keys: MemoryKeyStore(),
      prefs: await SharedPreferences.getInstance(),
    );
    final project = await app.addProject({
      'schemaVersion': 1,
      'title': 'Premium kafel',
      'summary': 's',
      'durationSec': 12.0,
      'aspectRatio': '9:16',
      'shots': [
        {'id': 's1', 'startSec': 0.0, 'endSec': 6.0, 'description': 'a'},
        {'id': 's2', 'startSec': 6.0, 'endSec': 12.0, 'description': 'b'},
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
    await tester.tap(find.textContaining('Kadr AI’ga ayting'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'sifatni tekshir');
    await tester.tap(find.text('Bajarish'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tekshiruv'), findsOneWidget);
    expect(find.textContaining('Birinchi kadr 6.0 s'), findsOneWidget);
    // Review alone changes nothing.
    expect(
      EditPlan.fromJson(app.byId(project.id)!.planJson).shots.first.motion,
      ShotMotion.none,
    );

    // "Tuzat" runs the suggested command for real.
    await tester.tap(find.text('Tuzat').first);
    await tester.pumpAndSettle();
    expect(find.text('AI montajchi taklifi'), findsOneWidget);
    await tester.tap(find.text('Qo‘llash'));
    await tester.pumpAndSettle();
    final plan = EditPlan.fromJson(app.byId(project.id)!.planJson);
    expect(plan.shots.first.motion, ShotMotion.punchIn);
    expect(plan.shots.first.duration, lessThanOrEqualTo(2.5));
  });
}
