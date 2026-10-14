// Screenshot tour of the main screens (light theme), for design review.
// Run with test_driver/screenshot_driver.dart (see there).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tour', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final app = AppController(
      keys: MemoryKeyStore(),
      prefs: await SharedPreferences.getInstance(),
    );
    await app.load();
    await app.refreshModelState();
    await app.memory.remember('Do‘konim nomi: Sumkachi');
    await tester.pumpWidget(HookkadrApp(controller: app));
    await tester.pump(const Duration(seconds: 2));

    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 600));
      await binding.takeScreenshot(name);
    }

    await shot('01_home');
    await tester.tap(find.text('AI Studiya'));
    await tester.pump(const Duration(seconds: 1));
    await shot('02_studio');
    await tester.tap(find.text('Shablonlar'));
    await tester.pump(const Duration(seconds: 1));
    await shot('03_templates');
    await tester.tap(find.text('Profil'));
    await tester.pump(const Duration(seconds: 1));
    await shot('04_profile');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
    await tester.pump(const Duration(seconds: 1));
    await shot('05_profile_kadr');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pump(const Duration(seconds: 1));
    await shot('06_profile_memory');
    await tester.tap(find.text('Bosh sahifa').first);
    await tester.pump(const Duration(seconds: 1));
    await shot('07_home_again');
  });
}
