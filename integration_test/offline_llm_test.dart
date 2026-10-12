import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/ai/offline_model.dart';
import 'package:hookkadr/features/ai/plan_generator.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('on-device model downloads, chats and plans offline', (
    tester,
  ) async {
    await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
    var last = 0.0;
    await OfflineLlm.install((p) => last = p);
    expect(await OfflineLlm.isInstalled(), isTrue);
    // ignore: avoid_print
    print('download progress reached ${(last * 100).round()}%');

    final reply = await OfflineLlm().complete(
      system: 'You are a helpful assistant. Answer in one short sentence.',
      messages: [
        {'role': 'user', 'content': 'What is video editing?'},
      ],
      maxTokens: 200,
    );
    // ignore: avoid_print
    print('OFFLINE REPLY: $reply');
    expect(reply.trim(), isNotEmpty);

    final plan = await PlanGenerator(planner: OfflineLlm()).fromPrompt(
      prompt: 'Kofe do‘koni uchun qisqa reklama',
      platform: 'Reels',
      durationSec: 15,
    );
    final p = EditPlan.fromJson(plan);
    // ignore: avoid_print
    print(
      'OFFLINE PLAN: ${p.shots.map((s) => '${s.duration}s ${s.description}').join(' || ')}',
    );
    expect(p.durationSec, 15);
    expect(p.shots.length, greaterThanOrEqualTo(2));
  }, timeout: const Timeout(Duration(minutes: 25)));
}
