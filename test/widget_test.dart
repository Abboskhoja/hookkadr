import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/ai/claude_frame_analyst.dart';
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
  testWidgets('home: one hero, four quick starts, five tabs, no tech words', (
    tester,
  ) async {
    final controller = await _controller();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);

    expect(find.text('Nima yaratamiz?'), findsOneWidget);
    // Kadr AI prepares itself: an honest status, no install step (the
    // banner, and the image card says the same).
    expect(find.text('Kadr AI tayyorlanmoqda'), findsWidgets);
    for (final t in [
      'Rasmlardan reklama',
      'AI video',
      'Reels uchun 5 ta g‘oya',
      'Bosh sahifa',
      'AI Studiya',
      'Loyihalar',
      'Shablonlar',
      'Profil',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.scrollUntilVisible(
      find.text('Videodan montaj'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Videodan montaj'), findsOneWidget);
    expect(find.text('Rasm yaratish'), findsOneWidget);
    expect(find.text('Qaysi AI bilan ishlaymiz?'), findsNothing);
    expect(find.textContaining('API'), findsNothing);
    expect(find.text('9:16'), findsNothing);
    await _teardown(tester);
  });

  for (final (w, h) in const [(360, 800), (390, 844), (393, 852), (412, 915)]) {
    testWidgets('home fits a $w×$h phone without overflow', (tester) async {
      final controller = await _controller(onboarded: true);
      tester.view.physicalSize = Size(w * 3.0, h * 3.0);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HookkadrApp(controller: controller));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      for (final tab in ['AI Studiya', 'Shablonlar', 'Profil']) {
        await tester.tap(find.text(tab));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: tab);
      }
      await _teardown(tester);
    });
  }

  testWidgets('a home quick start opens AI Studio in the right mode', (
    tester,
  ) async {
    final controller = await _controller(onboarded: true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);
    await tester.tap(find.text('Reels uchun 5 ta g‘oya'));
    await _settle(tester);
    // AI Studio opens in question mode with the idea already typed.
    expect(find.text('Salom! Men Kadr AI'), findsOneWidget);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.text, 'Reels uchun 5 ta g‘oya');
    await _teardown(tester);
  });

  testWidgets('templates are real recipes and profile is a tab', (
    tester,
  ) async {
    final controller = await _controller(onboarded: true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);
    await tester.tap(find.text('Shablonlar'));
    await _settle(tester);
    for (final t in [
      'Mahsulot reklamasi',
      'Instagram post reklama',
      'YouTube taqdimot',
      'Reels montaj',
      'Kino uslubida',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.tap(find.text('Profil'));
    await _settle(tester);
    expect(find.text('Profil va sozlamalar'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    await _teardown(tester);
  });

  testWidgets('choosing a mode sets the composer and a plain format pill', (
    tester,
  ) async {
    final controller = await _controller(onboarded: true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);
    await tester.tap(find.text('AI Studiya'));
    await _settle(tester);

    await tester.tap(find.text('Video yaratish'));
    await _settle(tester);
    expect(find.text('Telefon uchun · 30 s'), findsOneWidget);
    expect(find.textContaining('Qanday video kerak?'), findsOneWidget);

    await tester.tap(find.text('Telefon uchun · 30 s'));
    await _settle(tester);
    expect(find.text('Qanday bo‘lsin?'), findsOneWidget);
    await tester.tap(find.text('YouTube uchun'));
    await tester.tap(find.text('1 daqiqa'));
    await tester.tap(find.text('Tayyor'));
    await _settle(tester);
    expect(find.text('YouTube uchun · 60 s'), findsOneWidget);
    // Exact resolutions are a Pro detail.
    expect(find.text('Sifat (Pro)'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('"Eslab qol" is remembered on the phone without any model', (
    tester,
  ) async {
    final controller = await _controller(onboarded: true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);
    await tester.tap(find.text('AI Studiya'));
    await _settle(tester);
    await tester.enterText(
      find.byType(EditableText),
      'Eslab qol: do‘konim nomi Sumkachi',
    );
    await tester.tap(find.byIcon(LucideIcons.arrowUp));
    await _settle(tester);
    expect(find.textContaining('Eslab qoldim'), findsOneWidget);
    expect(controller.memory.facts, ['do‘konim nomi Sumkachi']);
    expect(
      controller.memory.promptContext(),
      contains('do‘konim nomi Sumkachi'),
    );
  });

  testWidgets('without AI the answer explains it and opens simple settings', (
    tester,
  ) async {
    final controller = await _controller(onboarded: true);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);
    await tester.tap(find.text('AI Studiya'));
    await _settle(tester);

    await tester.tap(find.text('Savol berish'));
    await _settle(tester);
    await tester.enterText(find.byType(EditableText), 'Reels uchun g‘oya ber');
    await tester.tap(find.byIcon(LucideIcons.arrowUp));
    await _settle(tester);
    expect(find.textContaining('Bu ish uchun Kadr AI kerak'), findsOneWidget);
    await tester.tap(find.text('Kadr AI’ni yoqish'));
    await _settle(tester);
    expect(find.text('Profil va sozlamalar'), findsOneWidget);
    // API keys stay hidden until Pro mode is switched on.
    expect(find.text('AI ulanishlari'), findsNothing);
    // On-device Kadr AI is offered first, before any account or key.
    expect(find.text('Kadr AI telefonda'), findsOneWidget);
    // Brain, painter and motion: only the brain can be installed first.
    expect(find.textContaining('Hozir tayyorlash ('), findsWidgets);
    expect(find.textContaining('o‘zi tayyorlaydi'), findsWidgets);
    expect(find.text('Avval “Miya”ni o‘rnating.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Avval “Rassom”ni o‘rnating.'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Avval “Rassom”ni o‘rnating.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pro rejim'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Pro rejim'));
    await _settle(tester);
    expect(controller.proMode, isTrue);
    expect(find.text('AI ulanishlari'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('dark is the default theme', (tester) async {
    final controller = await _controller(onboarded: true);
    final dispatcher = tester.platformDispatcher;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    dispatcher.platformBrightnessTestValue = Brightness.light;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HookkadrApp(controller: controller));
    await _settle(tester);
    final bg = tester
        .widget<Scaffold>(find.byType(Scaffold).first)
        .backgroundColor;
    expect(bg ?? AppPalette.dark.background, AppPalette.dark.background);
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

    test(
      'video watching needs Gemini or Claude (frames), not OpenAI',
      () async {
        expect(
          (await _controller(keys: {'openai_key': 'o'})).canWatchVideo,
          isFalse,
        );
        final claude = await _controller(keys: {'claude_key': 'c'});
        expect(claude.canWatchVideo, isTrue);
        // Claude looks at frames extracted on the phone: no 18 MB upload limit.
        expect(claude.analystHasSizeLimit, isFalse);
        expect(claude.videoAnalyst, isA<ClaudeFrameAnalyst>());
        final gemini = await _controller(keys: {'gemini_key': 'g'});
        expect(gemini.canWatchVideo, isTrue);
        expect(gemini.analystHasSizeLimit, isTrue);
        // Gemini wins when both are connected (it also hears the audio).
        final both = await _controller(
          keys: {'gemini_key': 'g', 'claude_key': 'c'},
        );
        expect(both.videoAnalyst, isA<GeminiClient>());
      },
    );
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
