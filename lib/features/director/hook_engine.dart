/// Opening styles the engine can write.
enum HookStyle {
  question,
  problem,
  curiosity,
  beforeAfter,
  visualSurprise,
  resultFirst,
  statement,
  demonstration,
  story,
  emotional,
  educational,
  productReveal,
}

/// What kind of video it is; picks wording and the visual direction.
enum AdKind { product, food, realEstate, interior, service, personal, generic }

class HookVariant {
  const HookVariant({
    required this.style,
    required this.text,
    required this.visual,
  });

  final HookStyle style;

  /// On-screen opening line (Uzbek, short).
  final String text;

  /// What the first shot should show.
  final String visual;
}

/// Writes opening-hook variants from a brief. Template based and
/// deterministic, so it works offline and is testable; it never invents
/// numbers, guarantees or superlatives the user did not provide. A connected
/// LLM can rewrite the variants — this is the safe floor.
abstract final class HookEngine {
  static AdKind kindOf(String brief) {
    final t = brief.toLowerCase();
    if (RegExp(r'kafel|plitka|oshxona|interyer|dizayn|mebel|parket')
        .hasMatch(t)) {
      return AdKind.interior;
    }
    if (RegExp(r'restoran|kafe\b|taom|ovqat|osh\b|pitsa|burger|desert')
        .hasMatch(t)) {
      return AdKind.food;
    }
    if (RegExp(r'uy\b|kvartira|yer\b|ko.chmas|ijara|turar joy').hasMatch(t)) {
      return AdKind.realEstate;
    }
    if (RegExp(r'xizmat|kurs|salon|ustaxona|konsalting|ta.lim').hasMatch(t)) {
      return AdKind.service;
    }
    if (RegExp(r'mahsulot|taqdimot|yangi|brend|telefon|kiyim|poyabzal')
        .hasMatch(t)) {
      return AdKind.product;
    }
    if (RegExp(r'vlog|shaxsiy|men\b|hikoya').hasMatch(t)) {
      return AdKind.personal;
    }
    return AdKind.generic;
  }

  /// [topic] is the subject in the user's words ("premium kafel").
  static List<HookVariant> generate({
    required String topic,
    AdKind? kind,
    int count = 5,
  }) {
    final t = topic.trim().isEmpty ? 'bu mahsulot' : topic.trim();
    final k = kind ?? kindOf(topic);
    final visual = switch (k) {
      AdKind.interior =>
        'Tayyor interyerning keng kadri, so‘ng sirt teksturasi',
      AdKind.food => 'Taomning yaqin kadri: bug‘, tekstura, birinchi tishlam',
      AdKind.realEstate => 'Kirishdan ichkariga sekin kamera harakati',
      AdKind.product => 'Mahsulot sekin aylanib, yorug‘lik bilan ochiladi',
      AdKind.service => 'Natija yoki mijozning birinchi taassuroti',
      AdKind.personal => 'Yuzga yaqin kadr, to‘g‘ridan-to‘g‘ri nigoh',
      AdKind.generic => 'Eng kuchli, eng harakatchan lavha',
    };
    final all = <HookVariant>[
      HookVariant(
        style: HookStyle.question,
        text: '$t — nega hamma shuni so‘rayapti?',
        visual: visual,
      ),
      HookVariant(
        style: HookStyle.problem,
        text: 'Hali ham eskicha usulda ishlayapsizmi?',
        visual: 'Muammo ko‘rinib turgan kadr, so‘ng keskin kesish',
      ),
      HookVariant(
        style: HookStyle.curiosity,
        text: 'Mana shu $t — oxirigacha ko‘ring',
        visual: visual,
      ),
      HookVariant(
        style: HookStyle.beforeAfter,
        text: 'Oldin va keyin: farqni ko‘ring',
        visual: 'Ekran ikkiga bo‘linadi: oldin / keyin',
      ),
      HookVariant(
        style: HookStyle.resultFirst,
        text: 'Natija shu. Endi qanday qilganimizni ko‘rsatamiz',
        visual: 'Tayyor natija birinchi, keyin jarayon',
      ),
      HookVariant(
        style: HookStyle.productReveal,
        text: 'Tanishing: $t',
        visual: 'Qora fondan mahsulot yorug‘lik bilan paydo bo‘ladi',
      ),
      HookVariant(
        style: HookStyle.demonstration,
        text: 'Ishlashini o‘z ko‘zingiz bilan ko‘ring',
        visual: 'Mahsulot ishlayotgan lavha, qo‘l bilan',
      ),
      HookVariant(
        style: HookStyle.statement,
        text: 'Sifat birinchi kadrdan ko‘rinadi',
        visual: visual,
      ),
      HookVariant(
        style: HookStyle.visualSurprise,
        text: 'Kutmagan burilish',
        visual: 'Kutilmagan yaqin kadr yoki o‘lcham o‘zgarishi',
      ),
      HookVariant(
        style: HookStyle.educational,
        text: '$t tanlashda 3 narsaga e’tibor bering',
        visual: 'Raqamli ro‘yxat bilan ketma-ket detal kadrlari',
      ),
    ];
    // Different kinds lead with different styles.
    final priority = switch (k) {
      AdKind.interior || AdKind.product => const [
        HookStyle.productReveal,
        HookStyle.resultFirst,
        HookStyle.curiosity,
        HookStyle.question,
        HookStyle.statement,
      ],
      AdKind.food => const [
        HookStyle.visualSurprise,
        HookStyle.curiosity,
        HookStyle.productReveal,
        HookStyle.question,
        HookStyle.demonstration,
      ],
      AdKind.service || AdKind.personal => const [
        HookStyle.problem,
        HookStyle.question,
        HookStyle.educational,
        HookStyle.resultFirst,
        HookStyle.beforeAfter,
      ],
      _ => const [
        HookStyle.curiosity,
        HookStyle.question,
        HookStyle.resultFirst,
        HookStyle.statement,
        HookStyle.problem,
      ],
    };
    int rank(HookVariant v) {
      final i = priority.indexOf(v.style);
      return i < 0 ? 99 : i;
    }

    all.sort((a, b) => rank(a).compareTo(rank(b)));
    return all.take(count.clamp(1, all.length)).toList();
  }
}
