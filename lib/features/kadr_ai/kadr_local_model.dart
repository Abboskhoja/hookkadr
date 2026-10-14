import 'dart:async';

import 'package:kadr_llm/kadr_llm.dart';

import '../ai/ai_clients.dart';
import 'chat_format.dart';
import 'kadr_painter.dart';
import 'model_catalog.dart';
import 'model_manager.dart';

/// Kadr AI running on the phone itself: no API key, no internet once the
/// model pack is installed. The loaded model stays in memory between
/// messages (loading takes seconds) until [unload].
class KadrLocalModel implements GrammarTextModel {
  KadrLocalModel(this.manager, {this.pack = KadrModelPack.brain});

  final KadrModelManager manager;
  final KadrModelPack pack;

  static KadrLlm? _llm;
  static String? _loadedPath;
  static Future<KadrLlm>? _loading;

  @override
  ProviderKind get kind => ProviderKind.offline;

  /// Keeps the reply in the user's chat language and honest about origin.
  static const identity =
      'Sen Kadr AI — HOOKKADR ilovasining telefonda ishlaydigan sun’iy intellekti '
      '(Gemma 4 asosida). Asosan o‘zbek tilida (lotin), foydalanuvchi boshqa tilda '
      'yozsa o‘sha tilda javob ber.';

  Future<KadrLlm> _model() async {
    final file = await manager.fileFor(pack);
    if (_llm != null && _loadedPath == file.path) return _llm!;
    if (!await manager.isInstalled(pack)) {
      throw const AiException(
        'Kadr AI modeli hali o‘rnatilmagan. Sozlamalar → Kadr AI telefonda → Yuklab olish.',
      );
    }
    return _loading ??= () async {
      try {
        // Phones under 8 GB cannot hold the brain and the painter at once.
        final ram = kadrDeviceRamBytes();
        if (ram > 0 && ram < 8 * 1024 * 1024 * 1024) KadrPainter.unload();
        final llm = await KadrLlm.load(
          file.path,
          contextSize: pack.contextSize,
        );
        _llm?.dispose();
        _llm = llm;
        _loadedPath = file.path;
        return llm;
      } on KadrLlmException catch (e) {
        throw AiException(e.message);
      } finally {
        _loading = null;
      }
    }();
  }

  /// Streams the reply token by token.
  Stream<String> stream({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 1024,
    double temperature = 0.4,
    String? grammar,
  }) async* {
    final llm = await _model();
    final prompt = KadrChatFormat.format(
      pack.chatFormat,
      system.isEmpty ? identity : '$identity\n\n$system',
      messages,
    );
    try {
      yield* llm.generate(
        prompt,
        temperature: temperature,
        maxTokens: maxTokens,
        grammar: grammar,
      );
    } on KadrLlmException catch (e) {
      throw AiException(e.message);
    }
  }

  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) async {
    final out = StringBuffer();
    await for (final piece in stream(
      system: system,
      messages: messages,
      maxTokens: maxTokens.clamp(64, 1536),
    )) {
      out.write(piece);
    }
    final text = out.toString().trim();
    if (text.isEmpty) throw const AiException('Kadr AI bo‘sh javob qaytardi.');
    return text;
  }

  @override
  Future<String> completeWithGrammar({
    required String system,
    required List<Map<String, String>> messages,
    required String grammar,
    int maxTokens = 600,
  }) async {
    final out = StringBuffer();
    await for (final piece in stream(
      system: system,
      messages: messages,
      maxTokens: maxTokens,
      temperature: 0.3,
      grammar: grammar,
    )) {
      out.write(piece);
    }
    return out.toString();
  }

  @override
  Future<void> verify() async {
    if (!await manager.isInstalled(pack)) {
      throw const AiException('Kadr AI modeli o‘rnatilmagan.');
    }
  }

  /// Stops the reply being generated now, if any.
  static void cancel() => _llm?.cancel();

  /// Frees the model's memory (e.g. when the app goes to the background).
  static void unload() {
    _llm?.dispose();
    _llm = null;
    _loadedPath = null;
  }
}
