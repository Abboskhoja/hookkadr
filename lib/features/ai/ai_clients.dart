import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'token_meter.dart';

class AiException implements Exception {
  const AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum ProviderKind { hookkadr, openrouter, claude, openai, gemini, offline }

extension ProviderInfo on ProviderKind {
  String get label => switch (this) {
    ProviderKind.hookkadr => 'HOOKKADR hisobi',
    ProviderKind.openrouter => 'Hisob (OpenRouter)',
    ProviderKind.claude => 'Claude',
    ProviderKind.openai => 'OpenAI',
    ProviderKind.gemini => 'Gemini',
    ProviderKind.offline => 'Offline AI',
  };

  String get role => switch (this) {
    ProviderKind.hookkadr => 'Kirish bilan — kalitsiz, kreditlar bilan',
    ProviderKind.openrouter =>
      'Bitta login: Claude, GPT, Gemini — suhbat, video tahlil, rasm',
    ProviderKind.claude => 'Ssenariy va montaj rejasi',
    ProviderKind.openai => 'Montaj rejasi va suhbat',
    ProviderKind.gemini => 'Videoni ko‘rib tahlil qilish',
    ProviderKind.offline => 'Internetsiz suhbat va reja (qurilmada)',
  };

  String get keyHint => switch (this) {
    ProviderKind.hookkadr => '',
    ProviderKind.openrouter => 'sk-or-...',
    ProviderKind.claude => 'sk-ant-...',
    ProviderKind.openai => 'sk-...',
    ProviderKind.gemini => 'AIza...',
    ProviderKind.offline => '',
  };

  String get keySource => switch (this) {
    ProviderKind.hookkadr => '',
    ProviderKind.openrouter => 'openrouter.ai',
    ProviderKind.claude => 'console.anthropic.com',
    ProviderKind.openai => 'platform.openai.com',
    ProviderKind.gemini => 'aistudio.google.com',
    ProviderKind.offline => '',
  };

  String get storageKey => '${name}_key';

  /// Honest capability flags used by the router.
  bool get canPlan => true;
  bool get needsKey =>
      this != ProviderKind.offline && this != ProviderKind.hookkadr;
  bool get canWatchVideo =>
      this == ProviderKind.gemini || this == ProviderKind.openrouter;

  /// Connected by signing in (OAuth) rather than pasting a key.
  bool get usesLogin =>
      this == ProviderKind.openrouter || this == ProviderKind.hookkadr;
}

/// Can watch a video file and describe it with timestamps.
abstract interface class VideoAnalyst {
  Future<String> analyzeVideo(String path);
}

/// Text-to-image generation.
abstract interface class ImageGenerator {
  Future<Uint8List> generateImage(String prompt, {String aspectRatio});
}

/// Shared prompt so every video-capable provider is asked the same thing.
const videoAnalysisPrompt =
    'Analyze this video as a professional video editor. Report precisely: '
    'total duration; every shot with start/end timestamps in seconds; camera '
    'movement and framing per shot; transitions and cut rhythm; on-screen '
    'text; speech (transcribe key lines with timestamps); music and sound '
    'effects; color grading and visual style; the strongest usable moments. '
    'Be factual and only describe what is really in the video.';

/// Anything that can answer a text conversation with a system prompt.
abstract class TextModel {
  ProviderKind get kind;
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  });

  /// Cheap authenticated request that proves the key works.
  Future<void> verify();
}

/// Runs an HTTP call with a timeout and turns transport failures into
/// readable [AiException]s. With [passThroughStatus] the caller interprets
/// HTTP error statuses itself (our own server sends structured errors).
Future<http.Response> guardRequest(
  Future<http.Response> Function() call,
  String who, {
  bool passThroughStatus = false,
}) async {
  try {
    final res = await call().timeout(const Duration(minutes: 3));
    if (passThroughStatus) return res;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AiException('$who kaliti noto‘g‘ri yoki ruxsat yo‘q.');
    }
    if (res.statusCode == 429) {
      throw AiException('$who limiti tugadi. Birozdan keyin urinib ko‘ring.');
    }
    if (res.statusCode >= 400) {
      throw AiException('$who xatosi (${res.statusCode}).');
    }
    return res;
  } on TimeoutException {
    throw AiException('$who javob bermadi (timeout).');
  } on SocketException {
    throw const AiException('Internet aloqasi yo‘q.');
  } on http.ClientException {
    throw const AiException('Tarmoq xatosi.');
  }
}

Map<String, dynamic> _json(http.Response r) =>
    jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;

class ClaudeClient implements TextModel {
  ClaudeClient(this.apiKey, {http.Client? client, this.model = defaultModel})
    : _client = client ?? http.Client();

  static const defaultModel = 'claude-sonnet-5-5';
  final String apiKey;
  final String model;
  final http.Client _client;

  @override
  ProviderKind get kind => ProviderKind.claude;

  Map<String, String> get _headers => {
    'x-api-key': apiKey,
    'anthropic-version': '2023-06-01',
    'content-type': 'application/json',
  };

  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) async {
    final res = await guardRequest(
      () => _client.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'max_tokens': maxTokens,
          'system': system,
          'messages': messages,
        }),
      ),
      'Claude',
    );
    final body = _json(res);
    final u = body['usage'] as Map<String, dynamic>?;
    TokenMeter.instance.record(
      kind,
      (u?['input_tokens'] as num?)?.toInt() ?? 0,
      (u?['output_tokens'] as num?)?.toInt() ?? 0,
    );
    final blocks = body['content'] as List;
    return blocks
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();
  }

  @override
  Future<void> verify() async {
    await guardRequest(
      () => _client.get(
        Uri.parse('https://api.anthropic.com/v1/models?limit=1'),
        headers: _headers,
      ),
      'Claude',
    );
  }
}

class OpenAiClient implements TextModel, ImageGenerator {
  OpenAiClient(this.apiKey, {http.Client? client, this.model = defaultModel})
    : _client = client ?? http.Client();

  /// Verify this id against your OpenAI account's available models.
  static const defaultModel = 'gpt-5';
  final String apiKey;
  final String model;
  final http.Client _client;

  @override
  ProviderKind get kind => ProviderKind.openai;

  Map<String, String> get _headers => {
    'authorization': 'Bearer $apiKey',
    'content-type': 'application/json',
  };

  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) async {
    final res = await guardRequest(
      () => _client.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': model,
          'max_completion_tokens': maxTokens,
          'messages': [
            {'role': 'system', 'content': system},
            ...messages,
          ],
        }),
      ),
      'OpenAI',
    );
    final body = _json(res);
    final u = body['usage'] as Map<String, dynamic>?;
    TokenMeter.instance.record(
      kind,
      (u?['prompt_tokens'] as num?)?.toInt() ?? 0,
      (u?['completion_tokens'] as num?)?.toInt() ?? 0,
    );
    final choices = body['choices'] as List?;
    final text = choices?.firstOrNull?['message']?['content'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const AiException('OpenAI bo‘sh javob qaytardi.');
    }
    return text;
  }

  static const imageModel = 'gpt-image-1';

  /// Text-to-image. Returns PNG bytes.
  @override
  Future<Uint8List> generateImage(
    String prompt, {
    String aspectRatio = '1:1',
  }) async {
    final size = switch (aspectRatio) {
      '9:16' || '4:5' => '1024x1536',
      '16:9' => '1536x1024',
      _ => '1024x1024',
    };
    final res = await guardRequest(
      () => _client.post(
        Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: _headers,
        body: jsonEncode({
          'model': imageModel,
          'prompt': prompt,
          'size': size,
          'n': 1,
        }),
      ),
      'OpenAI',
    );
    final b64 =
        (_json(res)['data'] as List?)?.firstOrNull?['b64_json'] as String?;
    if (b64 == null) throw const AiException('OpenAI rasm qaytarmadi.');
    return base64Decode(b64);
  }

  @override
  Future<void> verify() async {
    await guardRequest(
      () => _client.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: _headers,
      ),
      'OpenAI',
    );
  }
}

class GeminiClient implements TextModel, VideoAnalyst, ImageGenerator {
  GeminiClient(this.apiKey, {http.Client? client, this.model = defaultModel})
    : _client = client ?? http.Client();

  static const defaultModel = 'gemini-2.5-flash';
  static const maxInlineBytes = 18 * 1024 * 1024;
  final String apiKey;
  final String model;
  final http.Client _client;

  @override
  ProviderKind get kind => ProviderKind.gemini;

  Map<String, String> get _headers => {
    'x-goog-api-key': apiKey,
    'content-type': 'application/json',
  };

  Uri get _generate => Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
  );

  String _text(http.Response res) {
    final body = _json(res);
    final u = body['usageMetadata'] as Map<String, dynamic>?;
    TokenMeter.instance.record(
      kind,
      (u?['promptTokenCount'] as num?)?.toInt() ?? 0,
      (u?['candidatesTokenCount'] as num?)?.toInt() ?? 0,
    );
    final parts =
        (body['candidates'] as List?)?.firstOrNull?['content']?['parts']
            as List?;
    final text = parts?.map((p) => p['text'] ?? '').join();
    if (text == null || text.trim().isEmpty) {
      throw const AiException('Gemini bo‘sh javob qaytardi.');
    }
    return text;
  }

  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) async {
    final res = await guardRequest(
      () => _client.post(
        _generate,
        headers: _headers,
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': system},
            ],
          },
          'contents': [
            for (final m in messages)
              {
                'role': m['role'] == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': m['content']},
                ],
              },
          ],
          'generationConfig': {'maxOutputTokens': maxTokens},
        }),
      ),
      'Gemini',
    );
    return _text(res);
  }

  @override
  Future<void> verify() async {
    await guardRequest(
      () => _client.get(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?pageSize=1',
        ),
        headers: _headers,
      ),
      'Gemini',
    );
  }

  static const imageModel = 'gemini-2.5-flash-image';

  /// Verify this id in Google AI Studio; Veo model names change between
  /// releases.
  static const videoModel = 'veo-3.1-generate-preview';

  /// Text-to-image. Returns image bytes (PNG/JPEG).
  @override
  Future<Uint8List> generateImage(
    String prompt, {
    String aspectRatio = '1:1',
  }) async {
    final res = await guardRequest(
      () => _client.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$imageModel:generateContent',
        ),
        headers: _headers,
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseModalities': ['TEXT', 'IMAGE'],
            'imageConfig': {'aspectRatio': aspectRatio},
          },
        }),
      ),
      'Gemini',
    );
    final parts =
        (_json(res)['candidates'] as List?)?.firstOrNull?['content']?['parts']
            as List? ??
        const [];
    for (final p in parts) {
      final data = (p['inlineData'] ?? p['inline_data'])?['data'] as String?;
      if (data != null) return base64Decode(data);
    }
    throw const AiException(
      'Gemini rasm qaytarmadi (so‘rov rad etilgan bo‘lishi mumkin).',
    );
  }

  /// Text-to-video with Veo (long-running job). Downloads the MP4 to [savePath].
  /// [onStatus] receives human-readable progress.
  Future<void> generateVideo(
    String prompt, {
    required String savePath,
    String aspectRatio = '9:16',
    void Function(String status)? onStatus,
    Duration timeout = const Duration(minutes: 8),
  }) async {
    final ar = aspectRatio == '16:9' ? '16:9' : '9:16';
    final start = await guardRequest(
      () => _client.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$videoModel:predictLongRunning',
        ),
        headers: _headers,
        body: jsonEncode({
          'instances': [
            {'prompt': prompt},
          ],
          'parameters': {'aspectRatio': ar},
        }),
      ),
      'Veo',
    );
    final name = _json(start)['name'] as String?;
    if (name == null) throw const AiException('Veo ishni boshlamadi.');
    final deadline = DateTime.now().add(timeout);
    Map<String, dynamic> op;
    var polls = 0;
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 8));
      polls++;
      onStatus?.call('Video yaratilmoqda… (${polls * 8} s)');
      final r = await guardRequest(
        () => _client.get(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/$name'),
          headers: _headers,
        ),
        'Veo',
      );
      op = _json(r);
      if (op['done'] == true) break;
      if (DateTime.now().isAfter(deadline)) {
        throw const AiException('Video generatsiyasi juda uzoq davom etdi.');
      }
    }
    final err = op['error'];
    if (err != null) {
      throw AiException('Veo xatosi: ${(err as Map)['message'] ?? err}');
    }
    final samples =
        op['response']?['generateVideoResponse']?['generatedSamples'] as List?;
    final uri = samples?.firstOrNull?['video']?['uri'] as String?;
    if (uri == null) {
      throw const AiException(
        'Veo video qaytarmadi (so‘rov rad etilgan bo‘lishi mumkin).',
      );
    }
    onStatus?.call('Video yuklab olinmoqda…');
    final file = await guardRequest(
      () => _client.get(Uri.parse(uri), headers: _headers),
      'Veo',
    );
    await File(savePath).writeAsBytes(file.bodyBytes, flush: true);
  }

  /// Native video understanding via inline upload (size limited).
  @override
  Future<String> analyzeVideo(String path) async {
    final file = File(path);
    if (await file.length() > maxInlineBytes) {
      throw const AiException(
        'Video 18 MB dan katta. Qisqaroq (taxminan 60 soniyagacha) video tanlang.',
      );
    }
    final lower = path.toLowerCase();
    final mime = lower.endsWith('.mov')
        ? 'video/quicktime'
        : lower.endsWith('.webm')
        ? 'video/webm'
        : 'video/mp4';
    final bytes = await file.readAsBytes();
    final res = await guardRequest(
      () => _client.post(
        _generate,
        headers: _headers,
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'inline_data': {
                    'mime_type': mime,
                    'data': base64Encode(bytes),
                  },
                },
                {'text': videoAnalysisPrompt},
              ],
            },
          ],
        }),
      ),
      'Gemini',
    );
    return _text(res);
  }
}
