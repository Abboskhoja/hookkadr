import '../analysis/domain/edit_plan.dart';

enum Severity { info, warning, problem }

/// One thing the quality check found, with the command that would fix it.
class QcFinding {
  const QcFinding(this.severity, this.code, this.message, {this.fix});
  final Severity severity;
  final String code;
  final String message;

  /// A Kadr AI command that resolves it ("hookni kuchaytir"), if one exists.
  final String? fix;
}

/// Creative quality control: deterministic checks of a plan against short-
/// form editing practice. It reads only the plan and measured clip lengths;
/// it never claims to judge taste or predict views.
abstract final class QualityControl {
  static const maxCharsPerSecond = 17.0;

  static List<QcFinding> check(
    EditPlan plan, {
    Map<String, double> clipDurations = const {},
    Set<String> knownClipIds = const {},
  }) {
    final out = <QcFinding>[];
    final shots = [...plan.shots]
      ..sort((a, b) => a.startSec.compareTo(b.startSec));

    // Opening.
    final first = shots.first;
    if (first.duration > 3.5) {
      out.add(
        QcFinding(
          Severity.warning,
          'slow_open',
          'Birinchi kadr ${first.duration.toStringAsFixed(1)} s — '
              'e’tibor uchun ilk 3 soniya muhim.',
          fix: 'hookni kuchaytir',
        ),
      );
    }
    final hasHookText = plan.captions.any((c) => c.startSec < 1.0);
    if (!hasHookText && plan.durationSec <= 60) {
      out.add(
        const QcFinding(
          Severity.info,
          'no_hook_text',
          'Boshida matn yo‘q: qisqa videolarda ilk soniyada hook matni '
              'tomoshabinni ushlab turadi.',
          fix: 'hook yoz',
        ),
      );
    }

    // Pacing.
    final avg = plan.durationSec / shots.length;
    if (plan.durationSec <= 30 && avg > 6) {
      out.add(
        QcFinding(
          Severity.info,
          'slow_pace',
          'O‘rtacha kadr ${avg.toStringAsFixed(1)} s — qisqa video uchun sekin.',
        ),
      );
    }
    final tiny = shots.where((s) => s.duration < 0.8).length;
    if (tiny > 0) {
      out.add(
        QcFinding(
          Severity.warning,
          'tiny_shots',
          '$tiny ta kadr 0.8 s dan qisqa — ko‘z ulgurmaydi.',
        ),
      );
    }

    // Missing or broken media.
    final cards = shots.where((s) => s.sourceClipId == null).length;
    if (cards > 0) {
      out.add(
        QcFinding(
          Severity.problem,
          'missing_media',
          '$cards ta kadr uchun material yo‘q — eksportda matnli karta '
              'bo‘ladi. Video yoki rasm qo‘shing.',
        ),
      );
    }
    if (knownClipIds.isNotEmpty) {
      final unknown = shots
          .where(
            (s) =>
                s.sourceClipId != null &&
                !knownClipIds.contains(s.sourceClipId),
          )
          .length;
      if (unknown > 0) {
        out.add(
          QcFinding(
            Severity.problem,
            'unknown_clip',
            '$unknown ta kadr loyihada yo‘q klipga bog‘langan.',
          ),
        );
      }
    }
    for (final s in shots) {
      final len = clipDurations[s.sourceClipId];
      if (len != null && s.sourceOut != null && s.sourceOut! > len + 0.15) {
        out.add(
          QcFinding(
            Severity.problem,
            'range_outside',
            '${s.id}: manba ${s.sourceOut!.toStringAsFixed(1)} s, klip esa '
                '${len.toStringAsFixed(1)} s.',
          ),
        );
      }
    }

    // Same footage shown twice.
    final byClip = <String, List<Shot>>{};
    for (final s in shots) {
      if (s.sourceClipId != null &&
          s.sourceIn != null &&
          s.sourceOut != null &&
          !s.freeze) {
        byClip.putIfAbsent(s.sourceClipId!, () => []).add(s);
      }
    }
    var repeats = 0;
    for (final list in byClip.values) {
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i], b = list[j];
          final overlap =
              (a.sourceOut! < b.sourceOut! ? a.sourceOut! : b.sourceOut!) -
              (a.sourceIn! > b.sourceIn! ? a.sourceIn! : b.sourceIn!);
          if (overlap > 0.5) repeats++;
        }
      }
    }
    if (repeats > 0) {
      out.add(
        QcFinding(
          Severity.warning,
          'repeated_footage',
          'Bir xil lavha $repeats marta takrorlangan.',
        ),
      );
    }

    // Captions.
    final caps = [...plan.captions]
      ..sort((a, b) => a.startSec.compareTo(b.startSec));
    for (final (i, c) in caps.indexed) {
      final dur = c.endSec - c.startSec;
      final cps = c.text.length / dur;
      if (cps > maxCharsPerSecond) {
        out.add(
          QcFinding(
            Severity.problem,
            'caption_fast',
            '“${_short(c.text)}” ${dur.toStringAsFixed(1)} s ko‘rinadi — '
                'o‘qib bo‘lmaydi (${cps.toStringAsFixed(0)} belgi/s).',
          ),
        );
      }
      if (i > 0 && c.startSec < caps[i - 1].endSec - 0.05) {
        out.add(
          QcFinding(
            Severity.warning,
            'caption_overlap',
            '“${_short(c.text)}” oldingi matn ustiga tushadi.',
          ),
        );
      }
      if (c.text.length > 60) {
        out.add(
          QcFinding(
            Severity.warning,
            'caption_long',
            '“${_short(c.text)}” juda uzun (${c.text.length} belgi).',
          ),
        );
      }
    }

    // Ending.
    final tailStart = plan.durationSec - 3;
    final hasCta =
        plan.captions.any((c) => c.endSec > tailStart) || plan.logo != null;
    if (!hasCta && plan.durationSec >= 8) {
      out.add(
        const QcFinding(
          Severity.info,
          'no_cta',
          'Oxirida chaqiriq yoki logotip yo‘q.',
          fix: 'oxirida "Bog‘laning" chiqar',
        ),
      );
    }

    // Audio.
    final m = plan.music;
    if (m != null && m.volume > 0.7) {
      out.add(
        const QcFinding(
          Severity.warning,
          'music_loud',
          'Musiqa baland — nutq bosilib qolishi mumkin.',
          fix: 'musiqani pasaytir',
        ),
      );
    }
    if (m != null && m.fadeOutSec == 0) {
      out.add(
        const QcFinding(
          Severity.info,
          'music_no_fade',
          'Musiqa oxirida so‘nmaydi, keskin uziladi.',
        ),
      );
    }

    out.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return out;
  }

  static String _short(String s) =>
      s.length > 28 ? '${s.substring(0, 28)}…' : s;
}
