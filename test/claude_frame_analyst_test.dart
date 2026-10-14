import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/ai/claude_frame_analyst.dart';
import 'package:hookkadr/features/render/media_analyzer.dart';

void main() {
  group('sampleTimes', () {
    test('covers the opening, every scene cut and stays inside the clip', () {
      final t = sampleTimes(20, [5, 11.5]);
      expect(t.first, closeTo(0.3, 1e-9));
      expect(t.any((x) => (x - 5.25).abs() < 0.01), isTrue);
      expect(t.any((x) => (x - 11.75).abs() < 0.01), isTrue);
      expect(t.every((x) => x > 0 && x < 20), isTrue);
      expect(t, [...t]..sort());
    });

    test('is capped, spaced and keeps first and last', () {
      final cuts = [for (var i = 1; i < 40; i++) i * 1.5];
      final t = sampleTimes(60, cuts, maxFrames: 12);
      expect(t.length, lessThanOrEqualTo(12));
      for (var i = 1; i < t.length; i++) {
        expect(t[i] - t[i - 1], greaterThanOrEqualTo(0.79));
      }
      expect(t.first, lessThan(1));
      expect(t.last, greaterThan(55));
    });

    test('tiny and empty clips', () {
      expect(sampleTimes(0, const []), isEmpty);
      final t = sampleTimes(1.0, const []);
      expect(t, isNotEmpty);
      expect(t.every((x) => x <= 0.8 + 1e-9), isTrue);
    });
  });

  group('ClaudeFrameAnalyst', () {
    ClipEvidence evidence() => ClipEvidence(
      facts: const ClipFacts(
        id: 'clip',
        durationSec: 8,
        sceneCuts: [4],
        silences: [(start: 2.0, end: 3.0)],
      ),
      frames: [
        SampledFrame(0.3, Uint8List.fromList([1, 2, 3])),
        SampledFrame(4.2, Uint8List.fromList([4, 5, 6])),
      ],
    );

    test(
      'sends labelled frames + measured facts and returns the analysis',
      () async {
        late Map<String, dynamic> sent;
        late Map<String, String> headers;
        final client = MockClient((req) async {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          headers = req.headers;
          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'Shots: 0–4 s plitka, 4–8 s detal.'},
              ],
              'usage': {'input_tokens': 10, 'output_tokens': 5},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final analyst = ClaudeFrameAnalyst(
          ClaudeClient('sk-test', client: client),
          load: (_) async => evidence(),
        );
        final out = await analyst.analyzeVideo('/x.mp4');

        expect(headers['x-api-key'], 'sk-test');
        final content =
            ((sent['messages'] as List).single as Map)['content'] as List;
        final images = content.where((b) => (b as Map)['type'] == 'image');
        expect(images.length, 2);
        final texts = [
          for (final b in content)
            if ((b as Map)['type'] == 'text') b['text'] as String,
        ];
        expect(texts.first, 'Frame at 0.3 s');
        expect(texts, contains('Frame at 4.2 s'));
        expect(texts.last, contains('scene cuts at [4.0]'));
        expect(texts.last, contains('silent pauses [2.0–3.0]'));
        expect(
          (images.first as Map)['source'],
          containsPair('data', base64Encode([1, 2, 3])),
        );
        // The facts are returned together with Claude's description.
        expect(out, contains('Measured: duration 8.0 s'));
        expect(out, contains('plitka'));
        expect(sent['system'], contains('never invent speech'));
      },
    );

    test('no frames → clear error, no request', () async {
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      });
      final analyst = ClaudeFrameAnalyst(
        ClaudeClient('k', client: client),
        load: (_) async => const ClipEvidence(
          facts: ClipFacts(id: 'c', durationSec: 5),
          frames: [],
        ),
      );
      await expectLater(
        analyst.analyzeVideo('/x.mp4'),
        throwsA(isA<AiException>()),
      );
      expect(called, isFalse);
    });
  });
}
