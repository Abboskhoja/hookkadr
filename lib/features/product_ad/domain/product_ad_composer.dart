import '../../analysis/domain/edit_plan.dart';
import 'ad_copy.dart';

/// Turns product photos and ad copy into a premium, beat-locked EditPlan.
///
/// Timing is computed in whole video frames on a 90 BPM grid (one beat is
/// exactly 20 frames at 30 FPS), so every cut lands on a music beat and the
/// video is exactly the requested length. Pacing: a short hook, even middle
/// shots, and the most room for the call to action.
abstract final class ProductAdComposer {
  static const fps = 30;
  static const bpm = 90;
  static const _beatFrames = fps * 60 ~/ bpm; // 20
  static const minBeatsPerShot = 3; // 2.0 s: enough to read one line

  static Map<String, dynamic> compose({
    required List<String> clipIds,
    required AdCopy copy,
    required String title,
    int durationSec = 20,
    String aspectRatio = '9:16',
    String resolution = '1080p',
    String? musicPath,
  }) {
    final n = clipIds.length;
    final totalFrames = durationSec * fps;
    final totalBeats = totalFrames ~/ _beatFrames;
    if (n < 2) {
      throw ArgumentError.value(n, 'clipIds', 'at least 2 photos are needed');
    }
    if (n * minBeatsPerShot > totalBeats) {
      throw ArgumentError.value(
        n,
        'clipIds',
        'too many photos for $durationSec s (max ${totalBeats ~/ minBeatsPerShot})',
      );
    }

    final beats = _allocate(n, totalBeats);
    final shots = <Map<String, dynamic>>[];
    final captions = <Map<String, dynamic>>[];
    var cursor = 0;
    for (var i = 0; i < n; i++) {
      final last = i == n - 1;
      final frames = last ? totalFrames - cursor : beats[i] * _beatFrames;
      final start = cursor / fps;
      final end = (cursor + frames) / fps;
      cursor += frames;

      final String? text = i == 0
          ? copy.hook
          : last
          ? copy.cta
          : (i - 1 < copy.lines.length ? copy.lines[i - 1] : null);
      shots.add({
        'id': 's${i + 1}',
        'startSec': start,
        'endSec': end,
        'description':
            '${i == 0 ? 'Hook' : (last ? 'Chaqiriq' : 'Foto ${i + 1}')}'
            '${text == null ? '' : ' — $text'}',
        'camera': i == 0 ? 'Tez yaqinlashish' : 'Sekin yaqinlashish',
        'transitionIn': i == 0 ? 'qoradan chiqish' : 'yumshoq o‘tish',
        'transition': i == 0 ? 'fadeBlack' : 'crossfade',
        'transitionSec': i == 0 ? 0.6 : 0.5,
        'motion': i == 0 ? 'punchIn' : 'slowZoom',
        'sourceClipId': clipIds[i],
        'sourceIn': 0.0,
        'sourceOut': end - start,
      });
      if (text != null) {
        // Text appears after the dissolve and leaves just before the cut.
        final inset = i == 0 ? 0.3 : (last ? 0.4 : 0.35);
        captions.add({
          'startSec': start + inset,
          'endSec': end - 0.1,
          'text': text,
        });
      }
    }

    return {
      'schemaVersion': 1,
      'title': title.length > 48 ? '${title.substring(0, 48)}…' : title,
      'summary':
          'Mahsulot reklamasi: $n foto, $durationSec s, kesimlar $bpm BPM ritmda.',
      'durationSec': durationSec.toDouble(),
      'aspectRatio': aspectRatio,
      'shots': shots,
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': captions,
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': resolution, 'fps': fps},
      'grade': ColorGrade.presets['kino']!.toJson(),
      if (musicPath != null)
        'music': {
          'path': musicPath,
          'name': 'Kadr AI fon musiqasi',
          'volume': 0.55,
          'offsetSec': 0.0,
          'fadeInSec': 0.5,
          'fadeOutSec': 1.5,
          'beats': [for (var b = 0; b < totalBeats; b++) b * 60 / bpm],
        },
    };
  }

  /// Beats per shot: weights 0.75 (hook) / 1 / 1.3 (CTA), largest remainder,
  /// every shot at least [minBeatsPerShot], hook never longer than others.
  static List<int> _allocate(int n, int totalBeats) {
    final w = [
      for (var i = 0; i < n; i++) i == 0 ? 0.75 : (i == n - 1 ? 1.3 : 1.0),
    ];
    final sum = w.fold<double>(0, (a, b) => a + b);
    final raw = [for (final x in w) x / sum * totalBeats];
    final out = [for (final r in raw) r.floor()];
    final order = List.generate(n, (i) => i)
      ..sort((a, b) => (raw[b] - out[b]).compareTo(raw[a] - out[a]));
    var left = totalBeats - out.fold<int>(0, (a, b) => a + b);
    for (var k = 0; left > 0; k = (k + 1) % n, left--) {
      out[order[k]]++;
    }
    for (var i = 0; i < n; i++) {
      while (out[i] < minBeatsPerShot) {
        final donor = List.generate(
          n,
          (j) => j,
        ).reduce((a, b) => out[a] >= out[b] ? a : b);
        out[donor]--;
        out[i]++;
      }
    }
    final minOther = out.skip(1).reduce((a, b) => a < b ? a : b);
    if (out[0] > minOther) {
      final j = out.indexOf(minOther, 1);
      out[j] = out[0];
      out[0] = minOther;
    }
    return out;
  }
}
