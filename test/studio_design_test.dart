import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/chat/chat_screen.dart';
import 'package:hookkadr/features/home/home_screen.dart';
import 'package:hookkadr/features/montage/presentation/montage_screen.dart';
import 'package:hookkadr/features/home/templates_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 1.5),
    (const Size(1024, 768), 1.0),
  ]) {
    testWidgets('studio layout and routing $size scale $scale', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final app = AppController(
        keys: MemoryKeyStore(),
        prefs: await SharedPreferences.getInstance(),
      );
      KadrRequest? request;
      Widget wrap(Widget child) => AppScope(
        controller: app,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      );
      await tester.pumpWidget(
        wrap(
          HomeScreen(
            onAsk: (r) => request = r,
            onOpenProfile: () {},
            onOpenProjects: () {},
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold).first);
        await Future.wait([
          precacheImage(
            const AssetImage('assets/images/studio_hero.png'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/images/template_product.png'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/images/launcher_icon.png'),
            context,
          ),
        ]);
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width == 390) {
        await expectLater(
          find.byType(HomeScreen),
          matchesGoldenFile('goldens/studio_home.png'),
        );
      }
      await tester.tap(find.text('Yangi loyiha'));
      await tester.pumpAndSettle();
      expect(find.byType(MontageScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(MontageScreen))).pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Kadr AI bilan boshlash'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kadr AI bilan boshlash'));
      expect(request, isNotNull);
      await tester.scrollUntilVisible(
        find.text('Videodan montaj'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Videodan montaj'));
      expect(request!.mode, KadrMode.montage);
      await tester.pumpWidget(wrap(TemplatesScreen(onAsk: (r) => request = r)));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold).first);
        await Future.wait([
          precacheImage(
            const AssetImage('assets/images/studio_hero.png'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/images/template_product.png'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/images/launcher_icon.png'),
            context,
          ),
        ]);
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width == 390) {
        await expectLater(
          find.byType(TemplatesScreen),
          matchesGoldenFile('goldens/studio_templates.png'),
        );
      }
      await tester.scrollUntilVisible(
        find.text('Reels montaj'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reels montaj'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reels montaj'));
      expect(request!.mode, KadrMode.montage);
      expect(request!.aspect, '9:16');
      expect(request!.seconds, 15);
      expect(tester.takeException(), isNull);
    });
  }
}
