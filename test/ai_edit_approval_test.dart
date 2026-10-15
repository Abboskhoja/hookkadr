import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/editor/widgets/kadr_ai_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('offline AI requires approval; cancel preserves the project', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      keys: MemoryKeyStore(),
      prefs: await SharedPreferences.getInstance(),
    );
    final project = await app.addProject({
      'schemaVersion': 1,
      'title': 'Approval',
      'summary': 'Approval test',
      'durationSec': 8,
      'aspectRatio': '16:9',
      'shots': [
        {'id': 's1', 'startSec': 0, 'endSec': 8, 'description': 'Clip'},
      ],
      'mediaSlots': [],
      'captions': [],
      'audioTracks': [],
      'export': {'resolution': '720p', 'fps': 30},
    });
    var applied = 0;
    await tester.pumpWidget(
      AppScope(
        controller: app,
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => KadrAiSheet(
                    projectId: project.id,
                    onApplied: (_) => applied++,
                    onUndo: () async {},
                  ),
                ),
                child: const Text('Open AI'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open AI'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('9:16 qil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9:16 qil'));
    await tester.pumpAndSettle();
    expect(app.byId(project.id)!.planJson['aspectRatio'], '16:9');
    expect(applied, 0);
    expect(find.text('AI montajchi taklifi'), findsOneWidget);
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(app.byId(project.id)!.planJson['aspectRatio'], '16:9');
    await tester.ensureVisible(find.text('9:16 qil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9:16 qil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qo‘llash'));
    await tester.pumpAndSettle();
    expect(app.byId(project.id)!.planJson['aspectRatio'], '9:16');
    expect(applied, 1);
  });
}
