import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'ai_clients.dart';
import 'token_meter.dart';

/// One login, many models: OpenRouter exposes Claude, GPT and Gemini behind
/// an OpenAI-compatible API, and its official OAuth PKCE flow gives the app
/// a user-owned key without the user typing one.
class OpenRouterClient implements TextModel, VideoAnalyst, ImageGenerator {
  OpenRouterClient(this.apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  static const base = 'https://openrouter.ai/api/v1';

  /// Model choices (verified against /api/v1/models on 2026-10-12).
  static const planModel = 'anthropic/claude-sonnet-5.5';
  static const videoModel = 'google/gemini-3.8-flash'; // accepts video input
  static const imageModel = 'google/gemini-3.1-flash-image';

  /// Inline video upload limit we allow (data URL inside JSON).
  static const maxVideoBytes = 18 * 1024 * 1024;

  final String apiKey;
  final http.Client _client;

  @override
  ProviderKind get kind => ProviderKind.openrouter;

  Map<String, String> get _headers => {
    'authorization': 'Bearer $apiKey',
    'content-type': 'application/json',
    'X-Title': 'HOOKKADR',
  };

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await guardRequest(
      () => _client.post(
        Uri.parse('$base$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      'OpenRouter',
    );
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  String _text(Map<String, dynamic> body) {
    final u = body['usage'] as Map<String, dynamic>?;
    TokenMeter.instance.record(
      kind,
      (u?['prompt_tokens'] as num?)?.toInt() ?? 0,
      (u?['completion_tokens'] as num?)?.toInt() ?? 0,
    );
    final text =
        (body['choices'] as List?)?.firstOrNull?['message']?['content'];
    if (text is! String || text.trim().isEmpty) {
      throw const AiException('AI bo‘sh javob qaytardi.');
    }
    return text;
  }

  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) async => _text(
    await _post('/chat/completions', {
      'model': planModel,
      'max_tokens': maxTokens,
      'messages': [
        {'role': 'system', 'content': system},
        ...messages,
      ],
    }),
  );

  @override
  Future<void> verify() async {
    await guardRequest(
      () => _client.get(Uri.parse('$base/key'), headers: _headers),
      'OpenRouter',
    );
  }

  @override
  Future<String> analyzeVideo(String path) async {
    final file = File(path);
    if (await file.length() > maxVideoBytes) {
      throw const AiException('Video 18 MB dan katta. Qisqaroq video tanlang.');
    }
    final lower = path.toLowerCase();
    final mime = lower.endsWith('.mov')
        ? 'video/mov'
        : lower.endsWith('.webm')
        ? 'video/webm'
        : 'video/mp4';
    final data = base64Encode(await file.readAsBytes());
    return _text(
      await _post('/chat/completions', {
        'model': videoModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': videoAnalysisPrompt},
              {
                'type': 'video_url',
                'video_url': {'url': 'data:$mime;base64,$data'},
              },
            ],
          },
        ],
      }),
    );
  }

  @override
  Future<Uint8List> generateImage(
    String prompt, {
    String aspectRatio = '1:1',
  }) async {
    final body = await _post('/images', {
      'model': imageModel,
      'prompt': prompt,
      'aspect_ratio': aspectRatio,
    });
    final b64 = (body['data'] as List?)?.firstOrNull?['b64_json'] as String?;
    if (b64 == null) {
      throw const AiException(
        'Rasm qaytmadi (so‘rov rad etilgan bo‘lishi mumkin).',
      );
    }
    return base64Decode(b64);
  }
}

/// OAuth PKCE login with OpenRouter (official flow).
abstract final class OpenRouterAuth {
  static const callbackScheme = 'hookkadr';
  static const callbackUrl = 'hookkadr://auth';

  static String _verifier() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(48, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }

  static String challengeFor(String verifier) =>
      base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');

  static Uri authUrl({required String challenge, String? callback}) =>
      Uri.https('openrouter.ai', '/auth', {
        'callback_url': ?callback,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'key_label': 'HOOKKADR',
      });

  /// Opens the system browser sheet, returns the user's new API key.
  static Future<String> login({http.Client? client}) async {
    final verifier = _verifier();
    final url = authUrl(
      challenge: challengeFor(verifier),
      callback: callbackUrl,
    );
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackScheme,
      );
    } catch (_) {
      throw const AiException('Kirish bekor qilindi yoki yakunlanmadi.');
    }
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) throw const AiException('Kirish kodi qaytmadi.');
    return exchange(code: code, verifier: verifier, client: client);
  }

  /// Fallback for when the browser cannot return to the app: the user signs
  /// in without a callback, OpenRouter shows a code, the user pastes it.
  static ({Uri url, String verifier}) startManual() {
    final v = _verifier();
    return (url: authUrl(challenge: challengeFor(v)), verifier: v);
  }

  static Future<String> exchange({
    required String code,
    required String verifier,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    final res = await guardRequest(
      () => c.post(
        Uri.parse('${OpenRouterClient.base}/auth/keys'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'code': code.trim(),
          'code_verifier': verifier,
          'code_challenge_method': 'S256',
        }),
      ),
      'OpenRouter',
    );
    final key =
        (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['key'];
    if (key is! String || key.isEmpty) {
      throw const AiException('Kalit olinmadi.');
    }
    return key;
  }
}
