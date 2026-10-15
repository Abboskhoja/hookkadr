import 'dart:convert';
import 'dart:math' as math;

import '../analysis/domain/edit_plan.dart';

/// Pure edit operations on validated EditPlan JSON.
///
/// Shots form a magnetic (ripple) timeline like Final Cut's: changing one
/// shot shifts everything after it, so there are never gaps or overlaps.
/// Every operation returns a new map (the input is never mutated), which is
/// what makes undo/redo and version history trivial.
abstract final class PlanOps {
  static const minShot = 0.5;
  static const maxShot = 30.0;

  /// Beats further than this from a cut are ignored by [snapToBeats].
  static const beatSnapWindow = 0.6;

  static Map<String, dynamic> _copy(Map<String, dynamic> p) =>
      jsonDecode(jsonEncode(p)) as Map<String, dynamic>;

  static double _r(double v) => (v * 100).round() / 100;

  static List<Map<String, dynamic>> _shots(Map<String, dynamic> p) =>
      (p['shots'] as List).cast<Map<String, dynamic>>();

  static double _num(Object? v) => (v as num).toDouble();

  static double _dur(Map<String, dynamic> s) =>
      _num(s['endSec']) - _num(s['startSec']);

  static double _speed(Map<String, dynamic> s) =>
      (s['speed'] as num?)?.toDouble() ?? 1.0;

  /// Keeps a shot's source range in step with its timeline length
  /// (a 2× shot of 2 s uses 4 s of source).
  static void _setDuration(Map<String, dynamic> s, double d) {
    s['endSec'] = _num(s['startSec']) + d;
    if (s['sourceIn'] != null) {
      s['sourceOut'] = _r(_num(s['sourceIn']) + d * _speed(s));
    }
  }

  static String _newId(List<Map<String, dynamic>> shots) {
    var n = shots.length + 1;
    final ids = shots.map((s) => s['id']).toSet();
    while (ids.contains('s$n')) {
      n++;
    }
    return 's$n';
  }

  static int _index(List<Map<String, dynamic>> shots, String id) =>
      shots.indexWhere((s) => s['id'] == id);

  /// Sets a shot's timeline length (the right-edge trim). With
  /// [sourceLimit] — the source clip's length in seconds — the shot never
  /// reaches past the end of its footage.
  static Map<String, dynamic> resizeShot(
    Map<String, dynamic> plan,
    String shotId,
    double newDuration, {
    double? sourceLimit,
  }) {
    final p = _copy(plan);
    final shots = _shots(p);
    final i = _index(shots, shotId);
    if (i < 0) return p;
    final s = shots[i];
    var upper = maxShot;
    if (sourceLimit != null && s['sourceIn'] != null) {
      final cap = (sourceLimit - _num(s['sourceIn'])) / _speed(s);
      upper = cap.clamp(minShot, maxShot).toDouble();
    }
    final d = newDuration.clamp(minShot, upper).toDouble();
    final oldStart = _num(s['startSec']);
    final oldEnd = _num(s['endSec']);
    _setDuration(s, d);
    _anchorCaptions(p, oldStart, oldEnd, oldStart + d - oldEnd);
    return _ripple(p, shots);
  }

  static Map<String, dynamic>? removeShot(
    Map<String, dynamic> plan,
    String shotId,
  ) {
    final p = _copy(plan);
    final shots = _shots(p);
    if (shots.length <= 1) return null;
    shots.removeWhere((s) => s['id'] == shotId);
    return _ripple(p, shots);
  }

  /// Splits the shot under [atSec] (timeline time) into two. Returns null when
  /// either half would be shorter than [minShot].
  static Map<String, dynamic>? splitAt(
    Map<String, dynamic> plan,
    double atSec,
  ) {
    final p = _copy(plan);
    final shots = _shots(p);
    final i = shots.indexWhere(
      (s) => atSec > _num(s['startSec']) && atSec < _num(s['endSec']),
    );
    if (i < 0) return null;
    final a = shots[i];
    final head = atSec - _num(a['startSec']);
    final tail = _num(a['endSec']) - atSec;
    if (head < minShot || tail < minShot) return null;
    final b = Map<String, dynamic>.of(a)..['id'] = _newId(shots);
    _setDuration(a, head);
    b['startSec'] = atSec;
    b['endSec'] = atSec + tail;
    if (b['sourceIn'] != null) {
      final sp = _speed(b);
      b['sourceIn'] = _r(_num(b['sourceIn']) + head * sp);
      b['sourceOut'] = _r(_num(b['sourceIn']) + tail * sp);
    }
    shots.insert(i + 1, b);
    return _ripple(p, shots, keepOrder: true);
  }

  /// Inserts a copy right after the original.
  static Map<String, dynamic> duplicate(
    Map<String, dynamic> plan,
    String shotId,
  ) {
    final p = _copy(plan);
    final shots = _shots(p);
    final i = _index(shots, shotId);
    if (i < 0) return p;
    shots.insert(
      i + 1,
      Map<String, dynamic>.of(shots[i])..['id'] = _newId(shots),
    );
    return _ripple(p, shots, keepOrder: true);
  }

  /// Moves a shot one position left (-1) or right (+1).
  static Map<String, dynamic> move(
    Map<String, dynamic> plan,
    String shotId,
    int delta,
  ) {
    final p = _copy(plan);
    final shots = _shots(p);
    final i = _index(shots, shotId);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= shots.length) return p;
    shots.insert(j, shots.removeAt(i));
    return _ripple(p, shots, keepOrder: true);
  }

  /// Moves the in-point inside the source clip (keeps the out-point), the
  /// classic "trim start". Positive [deltaSec] removes footage.
  static Map<String, dynamic> trimStart(
    Map<String, dynamic> plan,
    String shotId,
    double deltaSec,
  ) {
    final p = _copy(plan);
    final shots = _shots(p);
    final i = _index(shots, shotId);
    if (i < 0) return p;
    final s = shots[i];
    if (s['sourceIn'] == null) return p;
    final dur = _dur(s);
    final sp = _speed(s);
    // Revealing earlier footage never grows the shot past [maxShot].
    final lowest = math.max(0.0, _num(s['sourceIn']) - (maxShot - dur) * sp);
    final newIn = (_num(s['sourceIn']) + deltaSec)
        .clamp(lowest, _num(s['sourceIn']) + (dur - minShot) * sp)
        .toDouble();
    final change = (newIn - _num(s['sourceIn'])) / sp; // timeline seconds
    final oldStart = _num(s['startSec']);
    final oldEnd = _num(s['endSec']);
    s['sourceIn'] = _r(newIn);
    s['endSec'] = oldStart + dur - change;
    _anchorCaptions(p, oldStart, oldEnd, -change);
    return _ripple(p, shots, keepOrder: true);
  }

  /// Inserts a [seconds]-long freeze of the frame under the playhead (the
  /// shot is split there first when possible).
  static Map<String, dynamic>? insertFreezeFrame(
    Map<String, dynamic> plan,
    double atSec, {
    double seconds = 1.0,
  }) {
    var p = splitAt(plan, atSec) ?? _copy(plan);
    final shots = _shots(p);
    // the shot that ends at (or contains) the playhead
    var i = shots.indexWhere((s) => (_num(s['endSec']) - atSec).abs() < 0.011);
    if (i < 0) {
      i = shots.indexWhere(
        (s) => atSec >= _num(s['startSec']) && atSec < _num(s['endSec']),
      );
    }
    if (i < 0) return null;
    final s = shots[i];
    if (s['sourceClipId'] == null || s['sourceIn'] == null) return null;
    final at = atSec.clamp(_num(s['startSec']), _num(s['endSec'])).toDouble();
    final srcT = _num(s['sourceIn']) + (at - _num(s['startSec'])) * _speed(s);
    final frame = <String, dynamic>{
      'id': _newId(shots),
      'startSec': 0.0,
      'endSec': seconds,
      'description': 'Freeze frame',
      'sourceClipId': s['sourceClipId'],
      'sourceIn': _r(srcT > 0.05 ? srcT - 0.04 : srcT),
      'sourceOut': _r((srcT > 0.05 ? srcT - 0.04 : srcT) + 0.04),
      'freeze': true,
    };
    shots.insert(i + 1, frame);
    p = _ripple(p, shots, keepOrder: true);
    return p;
  }

  /// Appends new media at the end of the timeline (one shot per clip).
  static Map<String, dynamic> appendShots(
    Map<String, dynamic> plan,
    List<({String clipId, double seconds, bool still})> items,
  ) {
    final p = _copy(plan);
    final shots = _shots(p);
    for (final it in items) {
      final d = it.seconds.clamp(minShot, maxShot).toDouble();
      shots.add({
        'id': _newId(shots),
        'startSec': 0.0,
        'endSec': d,
        'description': it.still ? 'Rasm' : 'Video',
        'sourceClipId': it.clipId,
        'sourceIn': 0.0,
        'sourceOut': d,
      });
    }
    return _ripple(p, shots, keepOrder: true);
  }

  /// Changes playback speed but keeps the same source footage, so the shot
  /// gets shorter (faster) or longer (slower) on the timeline.
  static Map<String, dynamic> setSpeed(
    Map<String, dynamic> plan,
    String shotId,
    double speed,
  ) {
    final p = _copy(plan);
    final shots = _shots(p);
    final i = _index(shots, shotId);
    if (i < 0) return p;
    final s = shots[i];
    final next = speed.clamp(0.25, 4.0).toDouble();
    final sourceLen = _dur(s) * _speed(s);
    s['speed'] = next;
    final d = (sourceLen / next).clamp(minShot, maxShot).toDouble();
    s['endSec'] = _num(s['startSec']) + d;
    if (s['sourceIn'] != null) {
      s['sourceOut'] = _r(_num(s['sourceIn']) + d * next);
    }
    return _ripple(p, shots, keepOrder: true);
  }

  /// Sets how [shotId] enters (null [shotId] = every shot after the first).
  static Map<String, dynamic> setTransition(
    Map<String, dynamic> plan,
    String? shotId,
    String transition, {
    double seconds = 0.4,
  }) {
    final p = _copy(plan);
    final shots = _shots(p);
    for (final (i, s) in shots.indexed) {
      if (shotId == null ? i > 0 : s['id'] == shotId) {
        s['transition'] = transition;
        s['transitionSec'] = seconds;
      }
    }
    return p;
  }

  /// Original clip audio: 0 mutes, 1 keeps, up to 2 boosts.
  static Map<String, dynamic> setShotVolume(
    Map<String, dynamic> plan,
    String shotId,
    double volume,
  ) {
    final p = _copy(plan);
    for (final s in _shots(p)) {
      if (s['id'] == shotId) {
        s['volume'] = _r(volume.clamp(0.0, 2.0).toDouble());
      }
    }
    return p;
  }

  static Map<String, dynamic> setMusicFadeIn(
    Map<String, dynamic> plan,
    double seconds,
  ) {
    final p = _copy(plan);
    final m = p['music'] as Map<String, dynamic>?;
    if (m != null) m['fadeInSec'] = _r(seconds.clamp(0.0, 10.0).toDouble());
    return p;
  }

  static Map<String, dynamic> setMotion(
    Map<String, dynamic> plan,
    String shotId,
    String motion,
  ) {
    final p = _copy(plan);
    for (final s in _shots(p)) {
      if (s['id'] == shotId) s['motion'] = motion;
    }
    return p;
  }

  static Map<String, dynamic> addCaption(
    Map<String, dynamic> plan, {
    required double startSec,
    required double endSec,
    required String text,
  }) {
    final p = _copy(plan);
    final total = _num(p['durationSec']);
    final s = startSec.clamp(0.0, total - 0.1).toDouble();
    final e = endSec.clamp(s + 0.1, total).toDouble();
    final caps = (p['captions'] as List).cast<Map<String, dynamic>>()
      ..add({'startSec': _r(s), 'endSec': _r(e), 'text': text});
    caps.sort((a, b) => _num(a['startSec']).compareTo(_num(b['startSec'])));
    p['captions'] = caps;
    return p;
  }

  static Map<String, dynamic> updateCaption(
    Map<String, dynamic> plan,
    int index,
    String text,
  ) {
    final p = _copy(plan);
    final caps = (p['captions'] as List).cast<Map<String, dynamic>>();
    if (index >= 0 && index < caps.length) caps[index]['text'] = text;
    return p;
  }

  static Map<String, dynamic> removeCaption(
    Map<String, dynamic> plan,
    int index,
  ) {
    final p = _copy(plan);
    final caps = (p['captions'] as List).cast<Map<String, dynamic>>();
    if (index >= 0 && index < caps.length) caps.removeAt(index);
    return p;
  }

  /// Sets (or with null removes) the background music layer.
  static Map<String, dynamic> setMusic(
    Map<String, dynamic> plan,
    Map<String, dynamic>? music,
  ) {
    final p = _copy(plan);
    if (music == null) {
      p.remove('music');
    } else {
      p['music'] = music;
    }
    return p;
  }

  static Map<String, dynamic> setMusicVolume(
    Map<String, dynamic> plan,
    double volume,
  ) {
    final p = _copy(plan);
    final m = p['music'] as Map<String, dynamic>?;
    if (m != null) m['volume'] = _r(volume.clamp(0.0, 1.0).toDouble());
    return p;
  }

  /// Sets (or with null removes) the whole-video colour grade.
  static Map<String, dynamic> setGrade(
    Map<String, dynamic> plan,
    ColorGrade? grade,
  ) {
    final p = _copy(plan);
    if (grade == null || grade.isNeutral) {
      p.remove('grade');
    } else {
      p['grade'] = {
        for (final e in grade.toJson().entries) e.key: _r(e.value as double),
      };
    }
    return p;
  }

  /// Puts [clipId] (an image) as the logo over the last [seconds] of the
  /// video, or with a null [clipId] removes it.
  static Map<String, dynamic> setLogo(
    Map<String, dynamic> plan,
    String? clipId, {
    double seconds = 2,
    double scale = 0.3,
  }) {
    final p = _copy(plan);
    if (clipId == null) {
      p.remove('logo');
    } else {
      final total = _num(p['durationSec']);
      p['logo'] = {
        'clipId': clipId,
        'durationSec': _r(seconds.clamp(0.5, total < 5 ? total : 5.0)),
        'scale': _r(scale.clamp(0.1, 0.8)),
      };
    }
    return p;
  }

  /// Changes output format: aspect ratio and/or frame rate.
  static Map<String, dynamic> setFormat(
    Map<String, dynamic> plan, {
    String? aspectRatio,
    int? fps,
  }) {
    final p = _copy(plan);
    if (aspectRatio != null) {
      if (!kAspectRatios.contains(aspectRatio)) {
        throw ArgumentError('Unsupported aspect ratio: $aspectRatio');
      }
      p['aspectRatio'] = aspectRatio;
    }
    if (fps != null) {
      if (!kSupportedFps.contains(fps)) {
        throw ArgumentError('Unsupported fps: $fps');
      }
      (p['export'] as Map<String, dynamic>)['fps'] = fps;
    }
    return p;
  }

  /// Moves every cut (and the end) to the nearest music beat within
  /// [beatSnapWindow], so cuts land on the rhythm. [beats] are song times;
  /// the music's offset is applied here. Shots never get shorter than
  /// [minShot]; cuts with no nearby beat stay where they were.
  static Map<String, dynamic> snapToBeats(
    Map<String, dynamic> plan,
    List<double> beats,
  ) {
    final p = _copy(plan);
    final music = p['music'] as Map<String, dynamic>?;
    final offset = music == null ? 0.0 : _num(music['offsetSec'] ?? 0);
    final grid = [
      for (final b in beats) b - offset,
    ].where((b) => b > 0).toList()..sort();
    if (grid.isEmpty) return p;
    final shots = _shots(p);
    var prev = 0.0;
    var originalEnd = 0.0;
    final newDurations = <double>[];
    for (final s in shots) {
      originalEnd += _dur(s);
      var best = originalEnd;
      var bestDist = beatSnapWindow;
      for (final b in grid) {
        final d = (b - originalEnd).abs();
        if (d < bestDist && b - prev >= minShot) {
          best = b;
          bestDist = d;
        }
      }
      if (best - prev < minShot) best = prev + minShot;
      newDurations.add(best - prev);
      prev = best;
    }
    for (final (i, s) in shots.indexed) {
      _setDuration(s, newDurations[i]);
    }
    return _ripple(p, shots, keepOrder: true);
  }

  /// Captions are anchored to the shots they sit on (like connected titles
  /// in a magnetic timeline): when the shot spanning [oldStart, oldEnd]
  /// changes length by [delta], captions that start after it shift with it,
  /// a caption crossing its end stretches/shrinks with it, and a caption
  /// inside it is clipped to the shot's new end (dropped if nothing is left).
  /// Audio tracks (music/voice beds) stay at their absolute times.
  /// Call before [_ripple], which then clips everything to the new length.
  static void _anchorCaptions(
    Map<String, dynamic> p,
    double oldStart,
    double oldEnd,
    double delta,
  ) {
    final list = (p['captions'] as List?)?.cast<Map<String, dynamic>>();
    if (list == null || delta.abs() < 1e-9) return;
    const eps = 1e-6;
    final newEnd = oldEnd + delta;
    final out = <Map<String, dynamic>>[];
    for (final c in list) {
      final s = _num(c['startSec']);
      final e = _num(c['endSec']);
      Map<String, dynamic> moved;
      if (s >= oldEnd - eps) {
        moved = {...c, 'startSec': _r(s + delta), 'endSec': _r(e + delta)};
      } else if (e > oldEnd + eps) {
        moved = {...c, 'endSec': _r(e + delta)};
      } else if (s >= oldStart - eps && e > newEnd) {
        moved = {...c, 'endSec': _r(newEnd)};
      } else {
        moved = c;
      }
      if (_num(moved['endSec']) - _num(moved['startSec']) >= 0.1) {
        out.add(moved);
      }
    }
    p['captions'] = out;
  }

  static Map<String, dynamic> _ripple(
    Map<String, dynamic> p,
    List<Map<String, dynamic>> shots, {
    bool keepOrder = false,
  }) {
    if (!keepOrder) {
      shots.sort((a, b) => _num(a['startSec']).compareTo(_num(b['startSec'])));
    }
    var cursor = 0.0;
    for (final s in shots) {
      final dur = _dur(s);
      s['startSec'] = _r(cursor);
      cursor += dur;
      s['endSec'] = _r(cursor);
    }
    final total = _r(cursor);
    p['shots'] = shots;
    p['durationSec'] = total;
    for (final key in const ['captions', 'audioTracks']) {
      final list = (p[key] as List).cast<Map<String, dynamic>>();
      p[key] = [
        for (final e in list)
          if (_num(e['startSec']) < total - 0.05)
            {...e, 'endSec': _num(e['endSec']) > total ? total : e['endSec']},
      ];
    }
    return p;
  }
}
