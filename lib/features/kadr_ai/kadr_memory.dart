import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'kadr_painter.dart';

/// What Kadr AI learns about its user, kept only on this phone.
///
/// Honest scope: the models' weights never change. Kadr AI "grows" by
/// remembering facts the user asked it to keep, which looks the user likes
/// (ratings and choices) and the formats they use, and by feeding that back
/// into its prompts and defaults. Everything can be viewed and erased.
class KadrMemory {
  KadrMemory(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _key = 'kadr_memory_v1';
  static const maxFacts = 20;
  static const maxFactChars = 160;

  final List<String> facts = [];

  /// style name → (likes, dislikes, times chosen).
  final Map<String, (int, int, int)> _styles = {};
  final Map<String, int> _aspects = {};

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      facts.addAll((j['facts'] as List? ?? const []).cast<String>());
      for (final e in (j['styles'] as Map? ?? const {}).entries) {
        final v = (e.value as List).cast<num>();
        _styles[e.key as String] = (v[0].toInt(), v[1].toInt(), v[2].toInt());
      }
      for (final e in (j['aspects'] as Map? ?? const {}).entries) {
        _aspects[e.key as String] = (e.value as num).toInt();
      }
    } catch (_) {
      // A damaged record is dropped rather than half-trusted.
      clear();
    }
  }

  Future<void> _save() => _prefs.setString(
    _key,
    jsonEncode({
      'facts': facts,
      'styles': {
        for (final e in _styles.entries)
          e.key: [e.value.$1, e.value.$2, e.value.$3],
      },
      'aspects': _aspects,
    }),
  );

  bool get isEmpty => facts.isEmpty && _styles.isEmpty && _aspects.isEmpty;

  /// "Eslab qol: …" / "Esda tut, …" → the fact to keep, else null.
  static String? factFrom(String message) {
    final m = RegExp(
      r'^\s*(?:kadr ai[,:]?\s*)?(?:eslab qol|esda tut|yodda tut|eslab qolgin)\b[\s,:;.-]*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(message);
    final fact = m?.group(1)?.trim();
    return fact == null || fact.length < 3 ? null : fact;
  }

  Future<void> remember(String fact) async {
    var f = fact.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (f.length > maxFactChars) f = '${f.substring(0, maxFactChars - 1)}…';
    facts.removeWhere((x) => x.toLowerCase() == f.toLowerCase());
    facts.add(f);
    while (facts.length > maxFacts) {
      facts.removeAt(0);
    }
    await _save();
  }

  Future<void> forget(String fact) async {
    facts.remove(fact);
    await _save();
  }

  /// The user picked [style] for a picture or video.
  Future<void> choseStyle(PaintStyle style) async {
    final (l, d, c) = _styles[style.name] ?? (0, 0, 0);
    _styles[style.name] = (l, d, c + 1);
    await _save();
  }

  /// 👍 (+1) or 👎 (-1) on something drawn in [style].
  Future<void> rate(PaintStyle style, int value) async {
    final (l, d, c) = _styles[style.name] ?? (0, 0, 0);
    _styles[style.name] = value > 0 ? (l + 1, d, c) : (l, d + 1, c);
    await _save();
  }

  Future<void> choseAspect(String aspect) async {
    _aspects[aspect] = (_aspects[aspect] ?? 0) + 1;
    await _save();
  }

  /// Smoothed preference: ratings weigh three times a plain choice; a style
  /// with no history scores 0, so nothing is preferred until there is
  /// evidence.
  double styleScore(PaintStyle style) {
    final (l, d, c) = _styles[style.name] ?? (0, 0, 0);
    return (3 * (l - d) + c) / (3 * (l + d) + c + 2);
  }

  /// The style to start with, or null when nothing has been learned yet.
  PaintStyle? get preferredStyle {
    PaintStyle? best;
    var bestScore = 0.0;
    for (final s in PaintStyle.values) {
      final v = styleScore(s);
      if (v > bestScore + 1e-9) {
        best = s;
        bestScore = v;
      }
    }
    return best;
  }

  /// Most used aspect ratio after at least 2 uses, else null.
  String? get preferredAspect {
    if (_aspects.isEmpty) return null;
    final top = _aspects.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return top.value >= 2 ? top.key : null;
  }

  /// Lines for the brain's system prompt (Uzbek), empty when nothing known.
  String promptContext() {
    if (facts.isEmpty && preferredStyle == null) return '';
    final b = StringBuffer('Foydalanuvchi haqida eslab qolganlaring:');
    for (final f in facts.reversed.take(12)) {
      b.write('\n- $f');
    }
    final s = preferredStyle;
    if (s != null) b.write('\n- Yoqtirgan vizual uslubi: ${s.label}');
    b.write(
      '\nBularni kerak bo‘lganda hisobga ol, lekin ularni keraksiz takrorlama.',
    );
    return b.toString();
  }

  /// Plain-language summary for the Profile screen.
  List<String> learned() => [
    if (preferredStyle != null)
      'Yoqtirgan uslubingiz: ${preferredStyle!.label}',
    if (preferredAspect != null) 'Ko‘p ishlatiladigan format: $preferredAspect',
    for (final s in PaintStyle.values)
      if (_styles[s.name] case (final l, final d, _) when l + d > 0)
        '${s.label}: 👍 $l · 👎 $d',
  ];

  Future<void> clear() async {
    facts.clear();
    _styles.clear();
    _aspects.clear();
    await _prefs.remove(_key);
  }
}
