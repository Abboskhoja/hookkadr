import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'ai_clients.dart';
import 'token_meter.dart';

/// Base URL of the HOOKKADR server, set at build time:
/// `--dart-define=HOOKKADR_API_URL=https://api.example.com`.
const kHookkadrApiUrl = String.fromEnvironment('HOOKKADR_API_URL');

/// Supplies the signed-in user's token for the server.
abstract interface class HookkadrSession {
  /// A fresh bearer token, or null when signed out.
  Future<String?> token();
}

/// Local development only (`--dart-define=HOOKKADR_DEV_UID=me`): talks to a
/// server started with `DEV_AUTH=1`. Production servers refuse these tokens.
class DevSession implements HookkadrSession {
  const DevSession(this.uid);
  final String uid;

  @override
  Future<String?> token() async => 'dev:$uid';
}

/// The "Cursor model": the user signs in to HOOKKADR, the server holds the
/// AI provider keys and charges the user's credits.
class HookkadrCloudClient implements TextModel, VideoAnalyst, ImageGenerator {
  HookkadrCloudClient({
    required this.baseUrl,
    required this.session,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final HookkadrSession session;
  final http.Client _client;

  /// Last balance the server reported (null until the first call).
  int? lastCredits;

  @override
  ProviderKind get kind => ProviderKind.hookkadr;

  Future<Map<String, String>> _auth() async {
    final t = await session.token();
    if (t == null) throw const AiException('HOOKKADR hisobiga kiring.');
    return {'authorization': 'Bearer $t'};
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = res.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final c = body['credits'];
      if (c is num) lastCredits = c.toInt();
      return body;
    }
    throw AiException(switch (res.statusCode) {
      401 => 'Sessiya tugagan. Qaytadan kiring.',
      402 => 'Kreditlar tugadi. Hisobingizni to‘ldiring.',
      413 => 'Video juda katta.',
      415 => 'Bu video formati qo‘llab-quvvatlanmaydi.',
      429 => 'Juda ko‘p so‘rov. Birozdan keyin urinib ko‘ring.',
      502 || 503 => 'AI xizmati hozir javob bermayapti. Qayta urinib ko‘ring.',
      _ => 'Server xatosi (${res.statusCode}).',
    });
  }

  /// Reads a required field; a malformed server reply is reported, never crashes.
  T _field<T>(Map<String, dynamic> body, String name) {
    final v = body[name];
    if (v is! T) throw const AiException('Server noto‘g‘ri javob qaytardi.');
    return v;
  }

  void _meter(Map<String, dynamic> body) {
    final u = body['usage'] as Map<String, dynamic>?;
    TokenMeter.instance.record(
      kind,
      (u?['inputTokens'] as num?)?.toInt() ?? 0,
      (u?['outputTokens'] as num?)?.toInt() ?? 0,
    );
  }

  Future<http.Response> _send(Future<http.Response> Function() call) =>
      guardRequest(call, 'HOOKKADR', passThroughStatus: true);

  /// Current balance from the server.
  Future<int> credits() async {
    final res = await _send(
      () async =>
          _client.get(Uri.parse('$baseUrl/v1/me'), headers: await _auth()),
    );
    return _field<num>(_decode(res), 'credits').toInt();
  }

  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) async {
    final res = await _send(
      () async => _client.post(
        Uri.parse('$baseUrl/v1/complete'),
        headers: {...await _auth(), 'content-type': 'application/json'},
        body: jsonEncode({
          'system': system,
          'messages': messages,
          'maxTokens': maxTokens.clamp(16, 8000),
        }),
      ),
    );
    final body = _decode(res);
    _meter(body);
    return _field<String>(body, 'text');
  }

  @override
  Future<void> verify() async => credits();

  @override
  Future<String> analyzeVideo(String path) async {
    final lower = path.toLowerCase();
    final mime = lower.endsWith('.mov')
        ? 'video/quicktime'
        : lower.endsWith('.webm')
        ? 'video/webm'
        : 'video/mp4';
    final res = await _send(() async {
      final req =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/video/analyze'))
            ..headers.addAll(await _auth())
            ..files.add(
              await http.MultipartFile.fromPath(
                'video',
                path,
                contentType: MediaType.parse(mime),
              ),
            );
      return http.Response.fromStream(await _client.send(req));
    });
    final body = _decode(res);
    _meter(body);
    return _field<String>(body, 'text');
  }

  @override
  Future<Uint8List> generateImage(
    String prompt, {
    String aspectRatio = '1:1',
  }) async {
    final res = await _send(
      () async => _client.post(
        Uri.parse('$baseUrl/v1/images'),
        headers: {...await _auth(), 'content-type': 'application/json'},
        body: jsonEncode({'prompt': prompt, 'aspectRatio': aspectRatio}),
      ),
    );
    return base64Decode(_field<String>(_decode(res), 'b64'));
  }
}
