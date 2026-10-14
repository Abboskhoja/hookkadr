import '../ai/plan_generator.dart';
import '../analysis/domain/edit_plan.dart';

/// Turns Kadr AI's storyboard scenes (painted stills or animated clips)
/// into a beat-locked EditPlan with captions and music.
///
/// Every cut lands on a 90 BPM beat (20 frames at 30 FPS). An animated clip
/// is 16 frames at 6 FPS = 2.667 s = exactly 4 beats, so live scenes need
/// no trimming; stills share the requested length in whole beats.
abstract final class KadrVideoComposer {
  static const fps = 30;
  static const bpm = 90;
  static const beatFrames = fps * 60 ~/ bpm; // 20
  static const minBeats = 3; // 2.0 s: time to read one caption

  /// Frames/FPS of an animated scene (see `KadrPainter.animate`).
  static const motionFrames = 16;
  static const motionFps = 6;
  static const motionBeats = 4;

  /// Beats per still scene: proportional to the storyboard's seconds,
  /// largest remainder, at least [minBeats] each, summing to [total].
  static List<int> allocate(List<double> weights, int total) {
    final n = weights.length;
    if (n * minBeats > total) {
      throw ArgumentError.value(
        n,
        'scenes',
        'too many scenes for $total beats',
      );
    }
    final sum = weights.fold<double>(0, (a, w) => a + (w <= 0 ? 1 : w));
    final spare = total - n * minBeats;
    final exact = [for (final w in weights) spare * (w <= 0 ? 1 : w) / sum];
    final beats = [for (final e in exact) minBeats + e.floor()];
    var left = total - beats.fold<int>(0, (a, b) => a + b);
    final order = List.generate(n, (i) => i)
      ..sort((a, b) {
        final c = (exact[b] - exact[b].floor()).compareTo(
          exact[a] - exact[a].floor(),
        );
        return c != 0 ? c : a.compareTo(b);
      });
    for (final i in order) {
      if (left == 0) break;
      beats[i]++;
      left--;
    }
    return beats;
  }

  static Map<String, dynamic> compose({
    required List<StoryScene> scenes,
    required List<String> clipIds,
    required String title,
    required bool live,
    int durationSec = 15,
    String aspectRatio = '9:16',
    String resolution = '1080p',
    String? musicPath,
  }) {
    final n = scenes.length;
    if (n < 2 || clipIds.length != n) {
      throw ArgumentError('need 2+ scenes, one clip per scene');
    }
    final beats = live
        ? List.filled(n, motionBeats)
        : allocate([
            for (final s in scenes) s.sec,
          ], durationSec * fps ~/ beatFrames);
    final totalBeats = beats.fold<int>(0, (a, b) => a + b);
    final shots = <Map<String, dynamic>>[];
    final captions = <Map<String, dynamic>>[];
    var cursor = 0;
    // Stills: the last scene absorbs the frames left after whole beats so
    // the video is exactly the requested length.
    final totalFrames = live ? totalBeats * beatFrames : durationSec * fps;
    for (var i = 0; i < n; i++) {
      final frames = i == n - 1 ? totalFrames - cursor : beats[i] * beatFrames;
      final start = cursor / fps;
      final end = (cursor + frames) / fps;
      cursor += frames;
      final cap = scenes[i].caption;
      shots.add({
        'id': 's${i + 1}',
        'startSec': start,
        'endSec': end,
        'description': scenes[i].prompt,
        'camera': live
            ? 'Kadr AI harakati'
            : (i == 0 ? 'Tez yaqinlashish' : 'Sekin yaqinlashish'),
        'transition': i == 0 ? 'fadeBlack' : 'crossfade',
        'transitionSec': i == 0 ? 0.5 : 0.4,
        'motion': live ? 'none' : (i == 0 ? 'punchIn' : 'slowZoom'),
        'sourceClipId': clipIds[i],
        'sourceIn': 0.0,
        'sourceOut': end - start,
      });
      if (cap != null && cap.trim().isNotEmpty) {
        captions.add({
          'startSec': start + 0.3,
          'endSec': end - 0.1,
          'text': cap.trim(),
        });
      }
    }
    final total = totalFrames / fps;
    return {
      'schemaVersion': 1,
      'title': title.length > 48 ? '${title.substring(0, 48)}…' : title,
      'summary': live
          ? 'Kadr AI videosi: $n ta jonli sahna, ${total.toStringAsFixed(1)} s, '
                'telefonda yaratildi.'
          : 'Kadr AI videosi: $n ta chizilgan sahna, ${total.toStringAsFixed(1)} s, '
                'telefonda yaratildi.',
      'durationSec': total,
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
}
