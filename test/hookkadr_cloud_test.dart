import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/ai/hookkadr_cloud.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

HookkadrCloudClient _client(MockClientHandler h) => HookkadrCloudClient(
  baseUrl: 'https://api.test',
  session: const DevSession('u1'),
  client: MockClient(h),
);

void main() {
  test('complete sends the session token and returns text + credits', () async {
    late http.Request seen;
    final c = _client((req) async {
      seen = req;
      return http.Response(
        jsonEncode({
          'text': 'reja',
          'usage': {'inputTokens': 10, 'outputTokens': 5},
          'cost': 1,
          'credits': 49,
        }),
        200,
      );
    });
    final text = await c.complete(
      system: 's',
      messages: [
        {'role': 'user', 'content': 'x'},
      ],
    );
    expect(text, 'reja');
    expect(c.lastCredits, 49);
    expect(seen.headers['authorization'], 'Bearer dev:u1');
    expect(seen.url.path, '/v1/complete');
  });

  test('server error codes become clear Uzbek messages', () async {
    for (final (code, needle) in [
      (401, 'kiring'),
      (402, 'Kredit'),
      (429, 'so‘rov'),
      (503, 'javob bermayapti'),
    ]) {
      final c = _client(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'x'},
          }),
          code,
        ),
      );
      await expectLater(
        c.complete(
          system: 's',
          messages: [
            {'role': 'user', 'content': 'x'},
          ],
        ),
        throwsA(
          predicate((e) => e is AiException && e.message.contains(needle)),
        ),
        reason: 'HTTP $code',
      );
    }
  });

  test('video is uploaded as multipart with the right content type', () async {
    final file = File('${Directory.systemTemp.path}/hk_cloud_test.mov')
      ..writeAsBytesSync([1, 2, 3]);
    late http.BaseRequest seen;
    final c = HookkadrCloudClient(
      baseUrl: 'https://api.test',
      session: const DevSession('u1'),
      client: MockClient.streaming((req, body) async {
        seen = req;
        final bytes = await body.toBytes();
        expect(
          utf8.decode(bytes, allowMalformed: true),
          contains('video/quicktime'),
        );
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(jsonEncode({'text': 'tahlil', 'credits': 40})),
          ),
          200,
        );
      }),
    );
    expect(await c.analyzeVideo(file.path), 'tahlil');
    expect(seen.url.path, '/v1/video/analyze');
  });

  test(
    'router prefers the HOOKKADR account for planning, video and images',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cloud = _client((_) async => http.Response('{}', 200));
      final app = AppController(
        keys: MemoryKeyStore(),
        prefs: await SharedPreferences.getInstance(),
        cloud: cloud,
      );
      await app.keys.write('gemini_key', 'g');
      await app.load();
      expect(app.plannerKind, ProviderKind.hookkadr);
      expect(app.videoAnalyst, same(cloud));
      expect(app.imageGenerator, same(cloud));
      expect(app.aiReady, isTrue);
    },
  );

  // Runs only against a live dev server:
  //   (cd server && DEV_AUTH=1 PROVIDERS=fake PORT=8787 DB_PATH=/tmp/hk.db npm start)
  //   HOOKKADR_E2E_URL=http://127.0.0.1:8787 flutter test test/hookkadr_cloud_test.dart
  final e2e = Platform.environment['HOOKKADR_E2E_URL'];
  test('end-to-end against the local server', () async {
    final c = HookkadrCloudClient(
      baseUrl: e2e!,
      session: const DevSession('e2e_user'),
    );
    final before = await c.credits();
    final text = await c.complete(
      system: 's',
      messages: [
        {'role': 'user', 'content': 'salom'},
      ],
    );
    expect(text, contains('[DEV FAKE] salom'));
    expect(c.lastCredits, lessThan(before));
    final img = await c.generateImage('kofe', aspectRatio: '9:16');
    expect(img.length, greaterThan(10));
  }, skip: e2e == null ? 'set HOOKKADR_E2E_URL to run' : false);
}
