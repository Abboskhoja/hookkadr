import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/ai/plan_generator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _planText(num endSec) => jsonEncode({
  'schemaVersion': 1,
  'title': 'T',
  'summary': 'S',
  'durationSec': 10,
  'aspectRatio': '9:16',
  'shots': [
    {'id': 's1', 'startSec': 0, 'endSec': endSec, 'description': 'd'},
  ],
  'mediaSlots': [],
  'captions': [],
  'audioTracks': [],
  'export': {'resolution': '1080p', 'fps': 30},
});

http.Response _claude(String text) => http.Response(
  jsonEncode({
    'content': [
      {'type': 'text', 'text': text},
    ],
  }),
  200,
);

void main() {
  test('retries once when the first plan is invalid, then succeeds', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return _claude(calls == 1 ? _planText(99) : 'Mana: ${_planText(10)}');
    });
    final gen = PlanGenerator(planner: ClaudeClient('k', client: client));
    final plan = await gen.fromPrompt(
      prompt: 'x',
      platform: 'TikTok',
      durationSec: 10,
    );
    expect(calls, 2);
    expect(plan['title'], 'T');
  });

  test('gives up with AiException after two invalid plans', () async {
    final client = MockClient((_) async => _claude(_planText(99)));
    final gen = PlanGenerator(planner: ClaudeClient('k', client: client));
    expect(
      () => gen.fromPrompt(prompt: 'x', platform: 'TikTok', durationSec: 10),
      throwsA(isA<AiException>()),
    );
  });

  test('reference mode requires a Gemini key', () async {
    final gen = PlanGenerator(
      planner: ClaudeClient('k', client: MockClient((_) async => _claude(''))),
    );
    expect(
      () => gen.fromClips(
        clips: const [ClipInput(id: 'clip_01', path: '/x.mp4')],
        prompt: '',
        platform: 'Reels',
        durationSec: 15,
      ),
      throwsA(isA<AiException>()),
    );
  });

  test('401 maps to a readable key error', () async {
    final client = MockClient((_) async => http.Response('', 401));
    final gen = PlanGenerator(planner: ClaudeClient('bad', client: client));
    expect(
      () => gen.fromPrompt(prompt: 'x', platform: 'TikTok', durationSec: 10),
      throwsA(
        predicate((e) => e is AiException && e.message.contains('kalit')),
      ),
    );
  });

  test('OpenAI adapter extracts the message text', () async {
    final client = MockClient((req) async {
      expect(req.headers['authorization'], 'Bearer k');
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'hello'},
            },
          ],
        }),
        200,
      );
    });
    final out = await OpenAiClient('k', client: client).complete(
      system: 's',
      messages: [
        {'role': 'user', 'content': 'x'},
      ],
    );
    expect(out, 'hello');
  });

  test('verify maps 401 to a readable key error', () async {
    final client = MockClient((_) async => http.Response('', 401));
    expect(
      () => OpenAiClient('bad', client: client).verify(),
      throwsA(
        predicate((e) => e is AiException && e.message.contains('kalit')),
      ),
    );
  });

  test('plan with a source range is parsed and invalid range rejected', () {
    final ok = jsonDecode(_planText(10)) as Map<String, dynamic>;
    (ok['shots'] as List)[0]['sourceClipId'] = 'clip_01';
    (ok['shots'] as List)[0]['sourceIn'] = 1;
    (ok['shots'] as List)[0]['sourceOut'] = 4;
    expect(EditPlan.fromJson(ok).shots.first.sourceClipId, 'clip_01');
    (ok['shots'] as List)[0]['sourceOut'] = 0.5;
    expect(
      () => EditPlan.fromJson(ok),
      throwsA(isA<EditPlanFormatException>()),
    );
  });

  test(
    'rejects a shot whose source range exceeds the real clip duration',
    () async {
      // First answer uses sourceOut 9 on a 5 s clip, second one is valid.
      var calls = 0;
      String plan(num out) {
        final m = jsonDecode(_planText(10)) as Map<String, dynamic>;
        final shot = (m['shots'] as List)[0] as Map<String, dynamic>;
        shot['sourceClipId'] = 'clip_01';
        shot['sourceIn'] = 0;
        shot['sourceOut'] = out;
        return jsonEncode(m);
      }

      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final text = body['messages'].toString();
        if (text.contains('CLIPS:')) {
          // planner call
          calls++;
          return _claude(calls == 1 ? plan(9) : plan(4));
        }
        return http.Response('{}', 200);
      });
      final gemini = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'a video'},
                  ],
                },
              },
            ],
          }),
          200,
        ),
      );
      final gen = PlanGenerator(
        planner: ClaudeClient('k', client: client),
        videoAnalyst: GeminiClient('g', client: gemini),
      );
      final tmp = File('${Directory.systemTemp.path}/hk_test_clip.mp4')
        ..writeAsBytesSync([0, 1, 2]);
      final out = await gen.fromClips(
        clips: [ClipInput(id: 'clip_01', path: tmp.path, durationSec: 5)],
        prompt: 'x',
        platform: 'TikTok',
        durationSec: 10,
      );
      expect(calls, 2);
      expect(((out['shots'] as List)[0] as Map)['sourceOut'], 4);
    },
  );
}
