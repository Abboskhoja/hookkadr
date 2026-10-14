// Kadr AI on-device brain, end to end, with the network forbidden.
//
// The model pack must already be on the device (the app downloads it once).
// On the simulator the test can copy it from the Mac (the simulator can read
// host paths); it is still SHA-256 verified before use:
//   flutter test integration_test/kadr_ai_offline_test.dart -d <sim> \
//     --dart-define=KADR_MODEL_SRC=$PWD/ai/data/llm/gemma-4-E2B-it-Q4_K_M.gguf
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/ai/plan_generator.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/kadr_ai/kadr_local_model.dart';
import 'package:hookkadr/features/kadr_ai/model_catalog.dart';
import 'package:hookkadr/features/kadr_ai/model_manager.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kadr_llm/kadr_llm.dart';

/// Any socket during this test is a failure: Kadr AI must not call out.
class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('network used during offline Kadr AI test');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kadr AI answers, plans and follows a command offline', (
    tester,
  ) async {
    final manager = KadrModelManager();
    final file = await manager.fileFor(KadrModelPack.brain);
    const src = String.fromEnvironment('KADR_MODEL_SRC');
    if (!file.existsSync() && src.isNotEmpty && File(src).existsSync()) {
      file.parent.createSync(recursive: true);
      await File(src).copy(file.path);
    }
    expect(
      file.existsSync(),
      isTrue,
      reason: 'model pack missing at ${file.path}',
    );
    final sw = Stopwatch()..start();
    expect(await manager.adoptExisting(KadrModelPack.brain), isTrue);
    // ignore: avoid_print
    print('KADR sha256 verified in ${sw.elapsedMilliseconds} ms');
    // ignore: avoid_print
    print(
      'KADR device RAM ${(kadrDeviceRamBytes() / 1e9).toStringAsFixed(1)} GB',
    );

    HttpOverrides.global = _NoNetwork();
    try {
      final kadr = KadrLocalModel(manager);

      // 1. Conversation in Uzbek.
      sw.reset();
      final answer = await kadr.complete(
        system: 'Qisqa javob ber.',
        messages: [
          {
            'role': 'user',
            'content': 'Reels videoda birinchi 3 soniya nega muhim?',
          },
        ],
        maxTokens: 160,
      );
      // ignore: avoid_print
      print('KADR answer (${sw.elapsedMilliseconds} ms): $answer');
      expect(answer.length, greaterThan(20));

      // 2. Structured command → JSON, constrained by a grammar.
      const grammar = r'''
root ::= "{" ws "\"intent\":" ws intent "," ws "\"seconds\":" ws seconds ws "}"
intent ::= "\"shorten\"" | "\"add_text\"" | "\"add_music\"" | "\"color\"" | "\"make_video\"" | "\"make_image\"" | "\"question\""
seconds ::= [0-9]+ | "null"
ws ::= [ \t\n]*
''';
      sw.reset();
      final out = StringBuffer();
      await for (final t in kadr.stream(
        system:
            'Buyruqni JSON ga aylantir. intent: shorten, add_text, add_music, color, '
            'make_video, make_image, question.',
        messages: [
          {'role': 'user', 'content': 'videoni 15 soniyaga qisqartir'},
        ],
        maxTokens: 40,
        temperature: 0,
        grammar: grammar,
      )) {
        out.write(t);
      }
      final cmd = jsonDecode(out.toString()) as Map<String, dynamic>;
      // ignore: avoid_print
      print('KADR command (${sw.elapsedMilliseconds} ms): $cmd');
      expect(cmd['intent'], 'shorten');
      expect(cmd['seconds'], 15);

      // 3. A real, validated edit plan from the offline planner path.
      sw.reset();
      final plan = await PlanGenerator(planner: kadr).fromPrompt(
        prompt: 'Kofe do‘koni uchun qisqa reklama',
        platform: 'Reels',
        durationSec: 15,
      );
      final p = EditPlan.fromJson(plan);
      // ignore: avoid_print
      print(
        'KADR plan (${sw.elapsedMilliseconds} ms): '
        '${p.shots.map((s) => '${s.duration}s ${s.description}').join(' | ')}',
      );
      expect(p.durationSec, 15);
      expect(p.shots.length, greaterThanOrEqualTo(2));
      // The model's own shots, not the generic fallback structure.
      expect(
        p.shots.map((s) => s.description).join(' '),
        isNot(contains('Asosiy qism')),
      );
      expect(kadr.kind, ProviderKind.offline);
    } finally {
      HttpOverrides.global = null;
      KadrLocalModel.unload();
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
