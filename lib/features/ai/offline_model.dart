import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import 'ai_clients.dart';

/// On-device LLM (no internet after the one-time download).
/// Qwen3 0.6B in LiteRT-LM format: Apache-2.0, not gated, ~590 MB.
class OfflineLlm implements TextModel {
  static const modelUrl =
      'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm';
  static const fileName = 'Qwen3-0.6B.litertlm';
  static const approxSizeMb = 590;
  static const label = 'Qwen3 0.6B';

  @override
  ProviderKind get kind => ProviderKind.offline;

  /// The LiteRT-LM native library aborts the process on the iOS simulator
  /// (observed with flutter_edge_ai 2.2.0), and a native abort cannot be
  /// caught in Dart. Refuse to load the model there.
  static bool get runsOnSimulator =>
      Platform.isIOS &&
      Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

  static InferenceInstallationBuilder _builder() => FlutterEdgeAi.installModel(
    modelType: ModelType.qwen3,
    fileType: ModelFileType.litertlm,
  ).fromNetwork(modelUrl);

  static Future<String?> _installedId() async {
    final ids = await FlutterEdgeAi.listInstalledModels();
    for (final id in ids) {
      if (id.contains('Qwen3-0.6B')) return id;
    }
    return null;
  }

  static Future<bool> isInstalled() async {
    try {
      return await _installedId() != null;
    } catch (_) {
      return false;
    }
  }

  /// Downloads (once) and activates the model. [onProgress] gets 0..1.
  static Future<void> install(void Function(double) onProgress) async {
    try {
      await _builder().withProgress((p) => onProgress(p / 100)).install();
    } catch (e) {
      throw AiException('Offline modelni yuklab bo‘lmadi: $e');
    }
  }

  static Future<void> uninstall() async {
    final id = await _installedId();
    if (id != null) await FlutterEdgeAi.uninstallModel(id);
  }

  /// Removes `<think>…</think>` blocks some Qwen builds still emit.
  static String stripThinking(String s) =>
      s.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();

  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) async {
    if (runsOnSimulator) {
      throw const AiException(
        'Offline AI iOS simulyatorida ishlamaydi (native kutubxona qulaydi). '
        'Haqiqiy iPhone yoki Android qurilmada sinab ko‘ring.',
      );
    }
    if (!FlutterEdgeAi.hasActiveModel()) {
      if (!await isInstalled()) {
        throw const AiException(
          'Offline model o‘rnatilmagan. AI ulanishlari bo‘limidan yuklab oling.',
        );
      }
      await _builder().install(); // already on disk: only re-activates
    }
    final model = await FlutterEdgeAi.getActiveModel(maxTokens: 4096);
    try {
      final chat = await model.createChat(
        systemInstruction: system,
        maxOutputTokens: maxTokens.clamp(256, 2048),
        temperature: 0.4,
      );
      // Small on-device models handle one flattened turn best.
      final prompt = StringBuffer();
      for (final m in messages) {
        if (messages.length > 1) {
          prompt.writeln(m['role'] == 'assistant' ? 'ASSISTANT:' : 'USER:');
        }
        prompt.writeln(m['content']);
      }
      await chat.addQueryChunk(
        Message.text(text: prompt.toString(), isUser: true),
      );
      final out = StringBuffer();
      await for (final r in chat.generateChatResponseAsync()) {
        if (r is TextResponse) out.write(r.token);
      }
      final text = stripThinking(out.toString());
      if (text.isEmpty) {
        throw const AiException('Offline model bo‘sh javob qaytardi.');
      }
      return text;
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException('Offline model xatosi: $e');
    } finally {
      await model.close();
    }
  }

  @override
  Future<void> verify() async {
    if (!await isInstalled()) {
      throw const AiException('Offline model o‘rnatilmagan.');
    }
  }
}
