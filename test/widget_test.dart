import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/chat/chat_models.dart';
import 'package:hookkadr/features/plan/plan_ops.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _plan() => {
  'durationSec': 10.0,
  'shots': [
    {'id': 'a', 'startSec': 0, 'endSec': 4},
    {'id': 'b', 'startSec': 4, 'endSec': 10},
  ],
  'captions': [
    {'startSec': 6, 'endSec': 10, 'text': 'x'},
  ],
  'audioTracks': [],
};

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

Future<AppController> _controller({
  Map<String, String> keys = const {},
  bool onboarded = false,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_done': onboarded});
  final store = MemoryKeyStore();
  for (final e in keys.entries) {
    await store.write(e.key, e.value);
  }
  final c = AppController(
    keys: store,
    prefs: await SharedPreferences.getInstance(),
  );
  await c.load();
  return c;
}

void main() {
  testWidgets('first run asks which AI to use and can be skipped', (
    tester,
  ) async {
    final controller = await _controller();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);

    expect(find.text('Qaysi AI bilan ishlaymiz?'), findsOneWidget);
    await tester.ensureVisible(find.text('Keyinroq ulayman'));
    await tester.pump();
    await tester.tap(find.text('Keyinroq ulayman'));
    await _settle(tester);

    expect(find.textContaining('bugun nima yaratamiz'), findsOneWidget);
    expect(controller.onboardingDone, isTrue);
    await _teardown(tester);
  });

  testWidgets('sending without a connected AI offers the connections screen', (
    tester,
  ) async {
    final controller = await _controller(onboarded: true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);

    await tester.enterText(find.byType(EditableText), 'Test video');
    await tester.tap(find.byIcon(LucideIcons.arrowUp));
    await _settle(tester);
    expect(find.text('AI ulanishlari'), findsWidgets);
    expect(find.textContaining('hali AI’ga ulanmaganman'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('logo has no fixed backdrop and page follows theme', (
    tester,
  ) async {
    final controller = await _controller(onboarded: true);
    final dispatcher = tester.platformDispatcher;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    dispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);
    Color bg() =>
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor!;
    // Page colours come from the palette tokens (logo PNG is transparent).
    expect(bg(), AppPalette.light.background);
    expect(find.byKey(const ValueKey('brand-logo')), findsOneWidget);
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await _settle(tester);
    expect(bg(), AppPalette.dark.background);
    expect(find.byKey(const ValueKey('brand-logo')), findsOneWidget);
    await _teardown(tester);
  });

  group('router', () {
    test('Auto prefers Claude, then OpenAI, then Gemini', () async {
      var c = await _controller(keys: {'gemini_key': 'g', 'openai_key': 'o'});
      expect(c.plannerKind, ProviderKind.openai);
      c = await _controller(keys: {'gemini_key': 'g', 'claude_key': 'c'});
      expect(c.plannerKind, ProviderKind.claude);
      c = await _controller(keys: {'gemini_key': 'g'});
      expect(c.plannerKind, ProviderKind.gemini);
      expect((await _controller()).plannerKind, isNull);
    });

    test('manual choice wins only when that provider is connected', () async {
      final c = await _controller(keys: {'claude_key': 'c', 'openai_key': 'o'});
      await c.setPreferred(ProviderKind.openai);
      expect(c.plannerKind, ProviderKind.openai);
      await c.disconnect(ProviderKind.openai);
      expect(c.preferred, isNull);
      expect(c.plannerKind, ProviderKind.claude);
    });

    test('video watching requires Gemini', () async {
      expect(
        (await _controller(keys: {'claude_key': 'c'})).canWatchVideo,
        isFalse,
      );
      expect(
        (await _controller(keys: {'gemini_key': 'g'})).canWatchVideo,
        isTrue,
      );
    });
  });

  test('projects persist across controller instances', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = AppController(keys: MemoryKeyStore(), prefs: prefs);
    await a.addProject({'title': 'Demo', 'durationSec': 10});
    final b = AppController(keys: MemoryKeyStore(), prefs: prefs);
    await b.load();
    expect(b.projects.single.name, 'Demo');
  });

  group('PlanOps', () {
    test('resize ripples following shots and clamps captions', () {
      final r = PlanOps.resizeShot(_plan(), 'a', 2);
      final shots = r['shots'] as List;
      expect(shots[0]['endSec'], 2.0);
      expect(shots[1]['startSec'], 2.0);
      expect(r['durationSec'], 8.0);
      expect((r['captions'] as List).single['endSec'], 8.0);
    });

    test('remove shot closes the gap; last shot cannot be removed', () {
      final r = PlanOps.removeShot(_plan(), 'a')!;
      expect((r['shots'] as List).single['startSec'], 0.0);
      expect(r['durationSec'], 6.0);
      expect(PlanOps.removeShot(r, 'b'), isNull);
    });

    test('minimum shot length is enforced', () {
      final r = PlanOps.resizeShot(_plan(), 'a', 0.1);
      expect((r['shots'] as List)[0]['endSec'], 0.5);
    });
  });

  test('chat history persists, newest first, and survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = AppController(keys: MemoryKeyStore(), prefs: prefs);
    final one =
        ChatRecord(id: '1', title: 'Birinchi', updatedAt: DateTime(2026, 1, 1))
          ..messages.addAll([
            Msg.user('salom', clipNames: ['clip_01 · a.mp4']),
            Msg.ai('reja tayyor', projectId: 'p1'),
            Msg.activity([ActivityStep('Tahlil', ActivityState.active)]),
          ]);
    await a.saveChat(one);
    await a.saveChat(
      ChatRecord(id: '2', title: 'Ikkinchi', updatedAt: DateTime(2026, 1, 2)),
    );
    final b = AppController(keys: MemoryKeyStore(), prefs: prefs);
    await b.load();
    expect(b.chats.map((c) => c.id), ['2', '1']);
    final restored = b.chatById('1')!;
    expect(restored.messages[0].clipNames, ['clip_01 · a.mp4']);
    expect(restored.messages[1].projectId, 'p1');
    // an interrupted run must not look like it is still working
    expect(restored.messages[2].steps!.single.state, ActivityState.failed);
  });
}
