import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/ai/intent.dart';
import 'package:hookkadr/features/ai/offline_model.dart';
import 'package:hookkadr/features/ai/plan_generator.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ChatIntent _i(String t, {bool project = false, bool clips = false}) =>
    detectIntent(t, hasProject: project, hasClips: clips);

void main() {
  group('intent', () {
    test('attached clips always mean an edit', () {
      expect(_i('salom', clips: true), ChatIntent.createPlan);
    });
    test('questions and greetings are conversation', () {
      expect(_i('Salom!'), ChatIntent.chat);
      expect(_i('Reels uchun eng yaxshi uzunlik qancha?'), ChatIntent.chat);
      expect(
        _i('Qanday qilib hook yaxshilanadi', project: true),
        ChatIntent.chat,
      );
      expect(_i('как сделать хороший монтаж?'), ChatIntent.chat);
    });
    test('video ideas create a plan, follow-ups edit it', () {
      expect(_i('20 soniyali restoran reklamasi'), ChatIntent.createPlan);
      expect(_i('3-kadrni qisqartir', project: true), ChatIntent.editPlan);
      expect(_i('tezroq qil', project: true), ChatIntent.editPlan);
    });
    test('image and generated video requests', () {
      expect(_i('Kofe chashkasining rasmini yarat'), ChatIntent.image);
      expect(_i('draw a poster for my cafe'), ChatIntent.image);
      expect(_i('Dengiz bo‘yida AI video generatsiya qil'), ChatIntent.video);
      expect(_i('Veo bilan 8 soniyali kadr yarat'), ChatIntent.video);
    });
  });

  group('offline plan builder', () {
    test('parses a shot list, scales to duration and is a valid plan', () {
      const raw = '''
1. 2 | Yaqin planda kofe | Ertalabki kofe
2. 4 | Barista ishlamoqda | -
3) 3 | Tayyor ichimlik | Bugun keling!
''';
      final plan = PlanGenerator.buildSimplePlan(
        raw: raw,
        idea: 'Kofe reklamasi',
        durationSec: 18,
        aspectRatio: '9:16',
        resolution: '1080p',
      );
      final p = EditPlan.fromJson(plan);
      expect(p.shots, hasLength(3));
      expect(p.shots.last.endSec, 18);
      expect(p.captions.map((c) => c.text), [
        'Ertalabki kofe',
        'Bugun keling!',
      ]);
    });

    test('assigns user clips with in-range source ranges', () {
      final plan = PlanGenerator.buildSimplePlan(
        raw: '3 | a | -\n3 | b | -\n3 | c | -',
        idea: 'x',
        durationSec: 9,
        aspectRatio: '9:16',
        resolution: '720p',
        clips: const [
          ClipInput(id: 'clip_01', path: '/a', durationSec: 4),
          ClipInput(id: 'clip_02', path: '/b', durationSec: 10),
        ],
      );
      final p = EditPlan.fromJson(plan);
      expect(p.shots.map((s) => s.sourceClipId), [
        'clip_01',
        'clip_02',
        'clip_01',
      ]);
      for (final s in p.shots.where((s) => s.sourceClipId == 'clip_01')) {
        expect(s.sourceOut!, lessThanOrEqualTo(4));
      }
    });

    test('garbage output falls back to an honest generic structure', () {
      final plan = PlanGenerator.buildSimplePlan(
        raw: 'Sorry, I cannot do that.',
        idea: 'Sayohat',
        durationSec: 10,
        aspectRatio: '1:1',
        resolution: '1080p',
        fallbackCount: 4,
      );
      final p = EditPlan.fromJson(plan);
      expect(p.shots, hasLength(4));
      expect(p.shots.first.description, contains('Sayohat'));
      expect(p.durationSec, 10);
    });

    test('thinking blocks are removed from offline answers', () {
      expect(OfflineLlm.stripThinking('<think>hmm</think>\nSalom'), 'Salom');
    });
  });

  group('generation adapters', () {
    test('Gemini image returns inline bytes', () async {
      final client = MockClient((req) async {
        expect(req.url.path, contains(GeminiClient.imageModel));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'ok'},
                    {
                      'inlineData': {
                        'mimeType': 'image/png',
                        'data': base64Encode([1, 2, 3]),
                      },
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final bytes = await GeminiClient(
        'k',
        client: client,
      ).generateImage('cat');
      expect(bytes, [1, 2, 3]);
    });

    test('OpenAI image decodes b64_json', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {
                'b64_json': base64Encode([9, 8]),
              },
            ],
          }),
          200,
        ),
      );
      expect(await OpenAiClient('k', client: client).generateImage('cat'), [
        9,
        8,
      ]);
    });

    test('Veo: starts a job, polls until done, downloads the file', () async {
      var polls = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith(':predictLongRunning')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['parameters']['aspectRatio'], '9:16');
          return http.Response(
            jsonEncode({'name': 'models/veo/operations/op1'}),
            200,
          );
        }
        if (req.url.path.endsWith('operations/op1')) {
          polls++;
          return http.Response(
            jsonEncode(
              polls < 2
                  ? {'done': false}
                  : {
                      'done': true,
                      'response': {
                        'generateVideoResponse': {
                          'generatedSamples': [
                            {
                              'video': {'uri': 'https://example.com/v.mp4'},
                            },
                          ],
                        },
                      },
                    },
            ),
            200,
          );
        }
        return http.Response.bytes([7, 7, 7], 200);
      });
      final out = '${Directory.systemTemp.path}/veo_test.mp4';
      await GeminiClient(
        'k',
        client: client,
      ).generateVideo('sea', savePath: out, aspectRatio: '4:5');
      expect(File(out).readAsBytesSync(), [7, 7, 7]);
      expect(polls, 2);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('AI images -> video', () {
    test('storyboard text is parsed into scenes', () {
      const raw =
          "1. 3 | A steaming cup of coffee on a wooden table, warm light | Ertalab boshlang\n"
          "2) 4 | Barista pouring milk, macro shot | -\n"
          "5 | Customer smiling, golden hour | Bugun keling!\n"
          "garbage line\n";
      final scenes = PlanGenerator.parseStoryboard(raw);
      expect(scenes, hasLength(3));
      expect(scenes[1].caption, isNull);
      expect(scenes[2].caption, 'Bugun keling!');
    });

    test('slideshow plan is valid, scaled and links one image per scene', () {
      final plan = PlanGenerator.buildSlideshowPlan(
        scenes: const [
          StoryScene(sec: 3, prompt: 'a', caption: 'Bir'),
          StoryScene(sec: 4, prompt: 'b'),
          StoryScene(sec: 3, prompt: 'c', caption: 'Uch'),
        ],
        durationSec: 20,
        aspectRatio: '9:16',
        resolution: '1080p',
        title: 'Kofe',
      );
      final p = EditPlan.fromJson(plan);
      expect(p.durationSec, 20);
      expect(p.shots.map((s) => s.sourceClipId), [
        'clip_01',
        'clip_02',
        'clip_03',
      ]);
      expect(p.shots.last.endSec, 20);
      expect(p.captions, hasLength(2));
    });
  });
}
