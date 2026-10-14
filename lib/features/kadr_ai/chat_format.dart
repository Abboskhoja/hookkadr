/// Turns a conversation into the exact prompt text a local model expects.
///
/// The runtime tokenizes with special tokens enabled, so control markers in
/// user text must never reach it verbatim: [sanitize] breaks them up.
abstract final class KadrChatFormat {
  static final _control = RegExp(r'<(\|?[A-Za-z_][A-Za-z0-9_]{0,31}\|?)>');

  static String sanitize(String text) =>
      text.replaceAllMapped(_control, (m) => '< ${m[1]}>');

  /// Gemma 4: `<|turn>role\ncontent<turn|>\n` … ending with an open model turn.
  /// Matches the GGUF's own Jinja template (checked with llama-server).
  static String gemma4(String system, List<Map<String, String>> messages) {
    final b = StringBuffer();
    if (system.trim().isNotEmpty) {
      b.write('<|turn>system\n${sanitize(system.trim())}<turn|>\n');
    }
    for (final m in messages) {
      final role = m['role'] == 'assistant' ? 'model' : 'user';
      b.write(
        '<|turn>$role\n${sanitize((m['content'] ?? '').trim())}<turn|>\n',
      );
    }
    b.write('<|turn>model\n');
    return b.toString();
  }

  static String format(
    String family,
    String system,
    List<Map<String, String>> messages,
  ) => switch (family) {
    'gemma4' => gemma4(system, messages),
    _ => throw ArgumentError('unknown chat format $family'),
  };
}
