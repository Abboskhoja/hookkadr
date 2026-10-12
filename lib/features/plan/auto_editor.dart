import '../render/media_analyzer.dart';

/// Deterministic, offline "quick montage": cuts out pauses, splits on scene
/// changes, opens with the most dynamic moment and keeps short-form pacing.
/// Produces a valid EditPlan JSON without any AI.
abstract final class AutoEditor {
  static const minPiece = 0.8;

  static List<({double start, double end})> usablePieces(ClipFacts f) {
    final bounds = <double>[
      0,
      ...f.sceneCuts.where((c) => c > 0 && c < f.durationSec),
      f.durationSec,
    ];
    var pieces = <({double start, double end})>[
      for (var i = 0; i < bounds.length - 1; i++)
        (start: bounds[i], end: bounds[i + 1]),
    ];
    for (final s in f.silences) {
      final next = <({double start, double end})>[];
      for (final p in pieces) {
        if (s.end <= p.start || s.start >= p.end) {
          next.add(p);
          continue;
        }
        if (s.start > p.start) next.add((start: p.start, end: s.start));
        if (s.end < p.end) next.add((start: s.end, end: p.end));
      }
      pieces = next;
    }
    return pieces.where((p) => p.end - p.start >= minPiece).toList();
  }

  static Map<String, dynamic> build({
    required List<ClipFacts> clips,
    required int targetSec,
    required String aspectRatio,
    required String resolution,
    required String title,
  }) {
    // Remaining usable ranges per clip; takes consume them front-to-back so
    // the same footage is never used twice.
    final remaining = {
      for (final c in clips)
        c.id: [
          for (final p in usablePieces(c)) [p.start, p.end],
        ],
    };
    final shotCount = (targetSec / 2.5).round().clamp(3, 24);
    final pace = (targetSec / shotCount).clamp(1.5, 4.0);

    final picks = <({String clip, double start, double end})>[];
    double total = 0;

    ({double start, double end})? take(String clipId, double want) {
      final q = remaining[clipId]!;
      while (q.isNotEmpty && q.first[1] - q.first[0] < minPiece) {
        q.removeAt(0);
      }
      if (q.isEmpty) return null;
      final piece = q.first;
      final len = want.clamp(minPiece, piece[1] - piece[0]).toDouble();
      final start = piece[0];
      piece[0] = start + len;
      if (piece[1] - piece[0] < minPiece) q.removeAt(0);
      return (start: start, end: start + len);
    }

    // Hook: the clip with the most scene changes opens with a short beat.
    final byMotion = [...clips]
      ..sort((a, b) => b.sceneCuts.length.compareTo(a.sceneCuts.length));
    for (final c in byMotion) {
      final t = take(c.id, 2.0);
      if (t == null) continue;
      picks.add((clip: c.id, start: t.start, end: t.end));
      total += t.end - t.start;
      break;
    }

    // Then round-robin in the user's order at short-form pace.
    var progress = true;
    while (total < targetSec - 0.5 && progress) {
      progress = false;
      for (final c in clips) {
        final left = targetSec - total;
        if (left < minPiece) break;
        final t = take(c.id, pace < left ? pace : left);
        if (t == null) continue;
        progress = true;
        picks.add((clip: c.id, start: t.start, end: t.end));
        total += t.end - t.start;
      }
    }

    double r(double v) => (v * 100).round() / 100;
    final shots = <Map<String, dynamic>>[];
    var cursor = 0.0;
    for (final (i, p) in picks.indexed) {
      final d = p.end - p.start;
      final start = r(cursor);
      cursor += d;
      final end = r(cursor);
      shots.add({
        'id': 's${i + 1}',
        'startSec': start,
        'endSec': end,
        'description':
            '${i == 0 ? 'Hook · ' : (i == picks.length - 1 ? 'Yakun · ' : '')}'
            '${p.clip} ${p.start.toStringAsFixed(1)}–${p.end.toStringAsFixed(1)} s',
        'transitionIn': i == 0 ? 'cut' : 'hard cut',
        'sourceClipId': p.clip,
        'sourceIn': r(p.start),
        'sourceOut': r(p.end),
      });
    }
    final removed = clips.fold<int>(0, (a, c) => a + c.silences.length);
    final duration = shots.isEmpty ? 0.0 : (shots.last['endSec'] as double);
    return {
      'schemaVersion': 1,
      'title': title.length > 48 ? '${title.substring(0, 48)}…' : title,
      'summary':
          'Avto-montaj: ${shots.length} kadr, ${duration.toStringAsFixed(1)} s'
          '${removed > 0 ? ', $removed ta pauza kesildi' : ''}.',
      'durationSec': duration,
      'aspectRatio': aspectRatio,
      'shots': shots,
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': <Map<String, dynamic>>[],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': resolution, 'fps': 30},
    };
  }
}
