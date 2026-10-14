/// On-screen words of a product ad: an opening hook, one short benefit per
/// middle photo, and a call to action. Lines are cleaned of model artefacts
/// (quotes, markdown) and kept short enough to read in about two seconds.
class AdCopy {
  AdCopy({
    required String hook,
    required List<String> lines,
    required String cta,
  }) : hook = _required(fit(hook), 'hook'),
       lines = [for (final l in lines) _required(fit(l), 'line')],
       cta = _required(fit(cta), 'cta');

  /// ~17 characters per second for ≥2 s on screen.
  static const maxChars = 34;

  final String hook;
  final List<String> lines;
  final String cta;

  static String _required(String v, String name) {
    if (v.isEmpty) throw ArgumentError.value(v, name, 'must not be empty');
    return v;
  }

  static final _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
    unicode: true,
  );

  /// Strips quotes/markdown/labels and cuts at a word boundary.
  static String fit(String raw) {
    var s = raw
        // Emoji and pictographs: the video font cannot draw them.
        .replaceAll(_emoji, '')
        .replaceAll(RegExp(r'[*_`#"“”«»]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        // List numbering the model adds ("1. ", "2) ", "- ").
        .replaceFirst(RegExp(r'^(\d{1,2}[.)]|[-–•])\s+'), '');
    if (s.length > maxChars) {
      final cut = s.substring(0, maxChars);
      final space = cut.lastIndexOf(' ');
      s = (space > maxChars ~/ 2 ? cut.substring(0, space) : cut).trimRight();
    }
    // An opening bracket without its closing one reads as a broken sentence.
    final open = s.lastIndexOf('(');
    if (open >= 0 && !s.substring(open).contains(')')) {
      s = s.substring(0, open).trimRight();
    }
    return s.replaceAll(RegExp(r'[,;:\-–]+$'), '').trimRight();
  }
}
