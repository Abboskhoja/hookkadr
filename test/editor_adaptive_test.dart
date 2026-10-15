import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/editor/editor_screen.dart';
import 'package:hookkadr/features/editor/widgets/editor_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await loader.load();
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await icons.load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('editor fits $size and preserves edits across preview mode', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final app = AppController(
        keys: MemoryKeyStore(),
        prefs: await SharedPreferences.getInstance(),
      );
      final project = await app.addProject({
        'schemaVersion': 1,
        'title': 'Mahsulot reklamasi',
        'summary': 'Sinov',
        'durationSec': 8,
        'aspectRatio': '9:16',
        'shots': [
          {'id': 's1', 'startSec': 0, 'endSec': 4, 'description': 'Kirish'},
          {'id': 's2', 'startSec': 4, 'endSec': 8, 'description': 'Yakun'},
        ],
        'mediaSlots': [],
        'captions': [],
        'audioTracks': [],
        'export': {'resolution': '720p', 'fps': 30},
      });
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            theme: buildTheme(Brightness.dark),
            home: EditorScreen(projectId: project.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(EditorScreen),
        matchesGoldenFile(
          'goldens/editor_${size.width.toInt()}_${size.height.toInt()}.png',
        ),
      );
      await tester.tap(find.byTooltip('Keyingi kadr'));
      await tester.pump();
      expect(
        tester.widget<EditorTimeline>(find.byType(EditorTimeline)).t,
        closeTo(1 / 30, 0.000001),
      );
      await tester.tap(find.byTooltip('Oldingi kadr'));
      await tester.pump();
      expect(tester.widget<EditorTimeline>(find.byType(EditorTimeline)).t, 0);
      await tester.tap(find.byKey(const ValueKey('shot-s1')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tanlovni yopish'), findsOneWidget);
      expect(find.byTooltip('Bo‘lish'), findsOneWidget);
      expect(find.byTooltip('Qo‘shish'), findsNothing);
      await tester.tap(find.byTooltip('Tanlovni yopish'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Qo‘shish'), findsOneWidget);
      expect(find.byTooltip('Bo‘lish'), findsNothing);
      await tester.tap(find.byTooltip('Ijro'));
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byTooltip('Ijro'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byTooltip('To‘liq preview'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Montajga qaytish'), findsOneWidget);
      await tester.tap(find.byTooltip('Montajga qaytish'));
      await tester.pumpAndSettle();
      expect(app.byId(project.id)!.planJson['durationSec'], 8);
      expect(tester.takeException(), isNull);
      for (final mode in [
        'Ixcham',
        'Kengaytirilgan',
        'Timeline fokus',
        'Standart',
      ]) {
        await tester.tap(find.byTooltip('Timeline maydoni'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(mode).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: mode);
      }
    });
  }
}
