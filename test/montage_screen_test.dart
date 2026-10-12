import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/montage/presentation/montage_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('montage page starts empty with the action disabled', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      keys: MemoryKeyStore(),
      prefs: await SharedPreferences.getInstance(),
    );
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        controller: app,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const MontageScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Montaj'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull); // no clips yet
    expect(find.byTooltip('Galereyadan video'), findsOneWidget);
    expect(find.byTooltip('Kamera'), findsOneWidget);
    expect(find.text('≈38 MB'), findsOneWidget); // 1080p · 30 s estimate
  });
}
