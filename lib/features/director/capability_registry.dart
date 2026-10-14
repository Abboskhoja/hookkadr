import '../ai/ai_clients.dart';

/// What the app might be asked to do with AI.
enum AiTask {
  planText,
  videoUnderstanding,
  imageGeneration,
  videoGeneration,
  speechToText,
}

class Capability {
  const Capability(
    this.task,
    this.provider, {
    required this.note,
    this.limits = '',
  });

  final AiTask task;
  final ProviderKind provider;

  /// Human note: what it really does here.
  final String note;
  final String limits;
}

/// What each connected provider can do in HOOKKADR today. Only things that
/// have an adapter in this codebase are listed. Prices are deliberately not
/// stored: they change; the provider's own tariff applies.
abstract final class CapabilityRegistry {
  static const all = [
    Capability(
      AiTask.planText,
      ProviderKind.hookkadr,
      note: 'Montaj rejasi (server)',
    ),
    Capability(AiTask.planText, ProviderKind.claude, note: 'Montaj rejasi'),
    Capability(AiTask.planText, ProviderKind.openai, note: 'Montaj rejasi'),
    Capability(AiTask.planText, ProviderKind.gemini, note: 'Montaj rejasi'),
    Capability(AiTask.planText, ProviderKind.openrouter, note: 'Montaj rejasi'),
    Capability(
      AiTask.planText,
      ProviderKind.offline,
      note: 'Kadr AI telefonda (Gemma 4 E2B), internetsiz',
      limits: '6 GB+ xotira; rasm va video yaratmaydi',
    ),
    Capability(
      AiTask.videoUnderstanding,
      ProviderKind.gemini,
      note: 'Videoni ovozi bilan ko‘radi',
      limits: '≈18 MB',
    ),
    Capability(
      AiTask.videoUnderstanding,
      ProviderKind.hookkadr,
      note: 'Gemini orqali (server)',
      limits: '≈18 MB',
    ),
    Capability(
      AiTask.videoUnderstanding,
      ProviderKind.openrouter,
      note: 'Video modeli orqali',
      limits: '≈18 MB',
    ),
    Capability(
      AiTask.videoUnderstanding,
      ProviderKind.claude,
      note: 'Kadrlar orqali ko‘radi, eshitmaydi',
      limits: 'hajm cheklovi yo‘q',
    ),
    Capability(
      AiTask.imageGeneration,
      ProviderKind.gemini,
      note: 'Gemini rasm',
    ),
    Capability(
      AiTask.imageGeneration,
      ProviderKind.openai,
      note: 'gpt-image-2.5',
    ),
    Capability(
      AiTask.imageGeneration,
      ProviderKind.hookkadr,
      note: 'Gemini rasm (server)',
    ),
    Capability(
      AiTask.imageGeneration,
      ProviderKind.openrouter,
      note: 'OpenRouter rasm',
    ),
    Capability(
      AiTask.videoGeneration,
      ProviderKind.gemini,
      note: 'Veo',
      limits: 'qisqa klip; model nomi kalit bilan tekshirilishi kerak',
    ),
  ];

  static const _order = [
    ProviderKind.hookkadr,
    ProviderKind.claude,
    ProviderKind.gemini,
    ProviderKind.openai,
    ProviderKind.openrouter,
    ProviderKind.offline,
  ];

  /// Video understanding prefers providers that hear the audio too.
  static const _videoOrder = [
    ProviderKind.gemini,
    ProviderKind.hookkadr,
    ProviderKind.openrouter,
    ProviderKind.claude,
  ];

  /// Usable providers for [task], best first, given what is connected.
  static List<Capability> available(AiTask task, Set<ProviderKind> connected) {
    final order = task == AiTask.videoUnderstanding ? _videoOrder : _order;
    final list = [
      for (final c in all)
        if (c.task == task && connected.contains(c.provider)) c,
    ];
    list.sort(
      (a, b) => order.indexOf(a.provider).compareTo(order.indexOf(b.provider)),
    );
    return list;
  }

  static Capability? best(AiTask task, Set<ProviderKind> connected) =>
      available(task, connected).firstOrNull;

  /// Honest "what is missing" text when nothing is connected for [task].
  static String missing(AiTask task) {
    final names = {
      for (final c in all)
        if (c.task == task && c.provider != ProviderKind.offline)
          c.provider.label,
    }.join(', ');
    return switch (task) {
      AiTask.speechToText =>
        'Nutqni matnga o‘girish hali ulanmagan (adapter yo‘q).',
      _ => 'Bu uchun AI ulang: $names (Sozlamalar → AI ulanishlari).',
    };
  }
}
