import '../../ai/ai_clients.dart';
import '../domain/ad_copy.dart';

class AdCopyResult {
  const AdCopyResult(this.copy, {required this.byAi});
  final AdCopy copy;

  /// False when Kadr AI is not installed or its answer was unusable and the
  /// neutral template was used instead. The UI says which one it was.
  final bool byAi;
}

/// Writes the ad's on-screen words with on-device Kadr AI, forced into an
/// exact shape by a grammar: one hook, one line per middle photo, one CTA.
class AdCopyWriter {
  const AdCopyWriter(this.model);
  final GrammarTextModel? model;

  static String grammar(int photos) {
    final middle = photos - 2;
    final fotos = middle > 0 ? '${List.filled(middle, 'foto').join(' ')} ' : '';
    return 'root ::= "HOOK: " l "\\n" $fotos"CTA: " l "\\n"\n'
        'foto ::= "FOTO: " l "\\n"\n'
        // A line may not start with a digit: no "1." list numbering.
        'l ::= [^\\n0-9] [^\\n]{2,${AdCopy.maxChars - 1}}\n';
  }

  Future<AdCopyResult> write({
    required String brief,
    required int photos,
  }) async {
    final m = model;
    if (m == null) return AdCopyResult(template(brief, photos), byAi: false);
    final middle = photos - 2;
    try {
      final raw = await m.completeWithGrammar(
        system: 'Sen tajribali reklama kopirayterisan. Faqat o‘zbek tilida (lotin) yoz.',
        messages: [
          {
            'role': 'user',
            'content':
                'Mahsulot: $brief\n'
                '$photos ta mahsulot fotosidan premium reklama video uchun ekrandagi '
                'matnlarni yoz.\n'
                'HOOK — birinchi soniyada e’tiborni tortadigan qisqa gap.\n'
                'FOTO — har bir foto uchun bitta qisqa afzallik ($middle ta).\n'
                'CTA — xaridga chaqiriq.\n'
                'Har biri ${AdCopy.maxChars} belgidan oshmasin. Narx, raqam yoki '
                'tasdiqlanmagan va’da o‘ylab topma.',
          },
        ],
        grammar: grammar(photos),
        maxTokens: 60 + 30 * photos,
      );
      final copy = parse(raw, middle);
      if (copy != null) return AdCopyResult(copy, byAi: true);
    } on AiException {
      // Falls through to the template; the result says it was not AI.
    }
    return AdCopyResult(template(brief, photos), byAi: false);
  }

  static AdCopy? parse(String raw, int middle) {
    String? hook, cta;
    final lines = <String>[];
    for (final l in raw.split('\n')) {
      final t = l.trim();
      if (t.startsWith('HOOK:')) hook = t.substring(5);
      if (t.startsWith('FOTO:')) lines.add(t.substring(5));
      if (t.startsWith('CTA:')) cta = t.substring(4);
    }
    if (hook == null || cta == null || lines.length != middle) return null;
    try {
      return AdCopy(hook: hook, lines: lines, cta: cta);
    } on ArgumentError {
      return null;
    }
  }

  static const _neutral = [
    'Sifatga e’tibor bilan',
    'Har kunga mos',
    'Zamonaviy ko‘rinish',
    'Har bir detal muhim',
    'Yaqindan ko‘ring',
    'Did bilan tanlangan',
    'Sizning tanlovingiz',
    'O‘zingiz ko‘ring',
  ];

  /// Neutral words without invented facts, used when Kadr AI cannot write.
  static AdCopy template(String brief, int photos) {
    final b = AdCopy.fit(brief);
    return AdCopy(
      hook: b.isEmpty ? 'Yangi mahsulot' : b,
      lines: [
        for (var i = 0; i < photos - 2; i++) _neutral[i % _neutral.length],
      ],
      cta: 'Hoziroq buyurtma bering',
    );
  }
}
