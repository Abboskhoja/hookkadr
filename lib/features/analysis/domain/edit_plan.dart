/// Versioned, provider-independent montage plan. Every AI provider result is
/// converted to this schema and validated before the app uses it.
const editPlanSchemaVersion = 1;

class EditPlanFormatException implements Exception {
  const EditPlanFormatException(this.message);
  final String message;
  @override
  String toString() => 'EditPlanFormatException: $message';
}

enum MediaKind { video, image, logo, text, audio }

/// How a shot enters from the previous one (rendered with FFmpeg `xfade`).
enum ShotTransition { cut, crossfade, fadeBlack, slide, zoom }

/// Camera-style motion applied to a shot.
enum ShotMotion { none, punchIn, slowZoom }

/// Playback speeds offered in the editor (AI may use any value in range).
const kMinSpeed = 0.25;
const kMaxSpeed = 4.0;

class Shot {
  const Shot({
    required this.id,
    required this.startSec,
    required this.endSec,
    required this.description,
    this.camera,
    this.transitionIn,
    this.mediaSlotId,
    this.sourceClipId,
    this.sourceIn,
    this.sourceOut,
    this.transition = ShotTransition.cut,
    this.transitionSec = 0.4,
    this.speed = 1.0,
    this.motion = ShotMotion.none,
    this.freeze = false,
    this.volume = 1.0,
  });

  factory Shot.fromJson(Map<String, dynamic> j) {
    final transition = j['transition'] == null
        ? ShotTransition.cut
        : ShotTransition.values.asNameMap()[j['transition']];
    if (transition == null) {
      throw EditPlanFormatException('Unknown transition: ${j['transition']}');
    }
    final motion = j['motion'] == null
        ? ShotMotion.none
        : ShotMotion.values.asNameMap()[j['motion']];
    if (motion == null) {
      throw EditPlanFormatException('Unknown motion: ${j['motion']}');
    }
    final speed = (j['speed'] as num?)?.toDouble() ?? 1.0;
    if (speed < kMinSpeed || speed > kMaxSpeed) {
      throw EditPlanFormatException(
        'Shot ${j['id']} speed must be $kMinSpeed..$kMaxSpeed',
      );
    }
    final volume = (j['volume'] as num?)?.toDouble() ?? 1.0;
    if (volume < 0 || volume > 2) {
      throw EditPlanFormatException('Shot ${j['id']} volume must be 0..2');
    }
    final tSec = (j['transitionSec'] as num?)?.toDouble() ?? 0.4;
    if (tSec < 0.1 || tSec > 2) {
      throw EditPlanFormatException(
        'Shot ${j['id']} transitionSec must be 0.1..2',
      );
    }
    return Shot._fromJson(j, transition, tSec, speed, motion);
  }

  factory Shot._fromJson(
    Map<String, dynamic> j,
    ShotTransition transition,
    double transitionSec,
    double speed,
    ShotMotion motion,
  ) => Shot(
    id: _str(j, 'id'),
    startSec: _num(j, 'startSec'),
    endSec: _num(j, 'endSec'),
    description: _str(j, 'description'),
    camera: j['camera'] as String?,
    transitionIn: j['transitionIn'] as String?,
    mediaSlotId: j['mediaSlotId'] as String?,
    sourceClipId: j['sourceClipId'] as String?,
    sourceIn: (j['sourceIn'] as num?)?.toDouble(),
    sourceOut: (j['sourceOut'] as num?)?.toDouble(),
    transition: transition,
    transitionSec: transitionSec,
    speed: speed,
    motion: motion,
    freeze: j['freeze'] as bool? ?? false,
    volume: (j['volume'] as num?)?.toDouble() ?? 1.0,
  );

  final String id;
  final double startSec;
  final double endSec;
  final String description;
  final String? camera;
  final String? transitionIn;
  final String? mediaSlotId;

  /// Optional link to a user-uploaded clip (e.g. "clip_02") and the range of
  /// that clip used by this shot.
  final String? sourceClipId;
  final double? sourceIn;
  final double? sourceOut;

  /// Entry transition from the previous shot (ignored on the first shot,
  /// except [ShotTransition.fadeBlack] which becomes a fade-in).
  final ShotTransition transition;
  final double transitionSec;

  /// 2.0 = twice as fast: the shot shows `duration × speed` of source.
  final double speed;
  final ShotMotion motion;

  /// Holds the frame at [sourceIn] for the whole shot (freeze frame).
  final bool freeze;

  /// Original clip audio gain: 0 = muted, 1 = as recorded, up to 2.
  final double volume;

  double get duration => endSec - startSec;
}

class MediaSlot {
  const MediaSlot({
    required this.id,
    required this.kind,
    required this.description,
    this.requiredDurationSec,
  });

  factory MediaSlot.fromJson(Map<String, dynamic> j) {
    final kind = MediaKind.values.asNameMap()[_str(j, 'kind')];
    if (kind == null) {
      throw EditPlanFormatException('Unknown media kind: ${j['kind']}');
    }
    return MediaSlot(
      id: _str(j, 'id'),
      kind: kind,
      description: _str(j, 'description'),
      requiredDurationSec: (j['requiredDurationSec'] as num?)?.toDouble(),
    );
  }

  final String id;
  final MediaKind kind;
  final String description;
  final double? requiredDurationSec;
}

class Caption {
  const Caption({
    required this.startSec,
    required this.endSec,
    required this.text,
  });

  factory Caption.fromJson(Map<String, dynamic> j) => Caption(
    startSec: _num(j, 'startSec'),
    endSec: _num(j, 'endSec'),
    text: _str(j, 'text'),
  );

  final double startSec;
  final double endSec;
  final String text;
}

class AudioTrack {
  const AudioTrack({
    required this.kind,
    required this.startSec,
    required this.endSec,
    required this.description,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> j) => AudioTrack(
    kind: _str(j, 'kind'),
    startSec: _num(j, 'startSec'),
    endSec: _num(j, 'endSec'),
    description: _str(j, 'description'),
  );

  final String kind; // music | voiceover | sfx
  final double startSec;
  final double endSec;
  final String description;
}

class ExportOptions {
  const ExportOptions({required this.resolution, required this.fps});

  factory ExportOptions.fromJson(Map<String, dynamic> j) => ExportOptions(
    resolution: _str(j, 'resolution'),
    fps: _num(j, 'fps').toInt(),
  );

  final String resolution;
  final int fps;
}

/// Background music layer (a user-supplied audio file).
class MusicTrack {
  const MusicTrack({
    required this.path,
    required this.name,
    this.volume = 0.35,
    this.offsetSec = 0,
    this.fadeOutSec = 1.5,
    this.fadeInSec = 0,
    this.beats = const [],
    this.peaks = const [],
  });

  factory MusicTrack.fromJson(Map<String, dynamic> j) {
    final m = MusicTrack(
      path: _str(j, 'path'),
      name: _str(j, 'name'),
      volume: (j['volume'] as num?)?.toDouble() ?? 0.35,
      offsetSec: (j['offsetSec'] as num?)?.toDouble() ?? 0,
      fadeOutSec: (j['fadeOutSec'] as num?)?.toDouble() ?? 1.5,
      fadeInSec: (j['fadeInSec'] as num?)?.toDouble() ?? 0,
      beats: [
        for (final b in (j['beats'] as List? ?? const []))
          (b as num).toDouble(),
      ],
    );
    if (m.volume < 0 || m.volume > 1) {
      throw const EditPlanFormatException('music.volume must be 0..1');
    }
    if (m.offsetSec < 0 || m.fadeOutSec < 0) {
      throw const EditPlanFormatException('music offset/fade must be >= 0');
    }
    return m;
  }

  final String path;
  final String name;

  /// 0..1 relative to clip audio (dialogue stays at 1).
  final double volume;

  /// Where in the song the video starts.
  final double offsetSec;
  final double fadeOutSec;
  final double fadeInSec;

  /// Detected beat times in the song (seconds), used for beat sync.
  final List<double> beats;

  /// Waveform: loudness every 0.1 s of the song, 0..1.
  final List<double> peaks;
}

class EditPlan {
  const EditPlan({
    required this.title,
    required this.summary,
    required this.durationSec,
    required this.aspectRatio,
    required this.shots,
    required this.mediaSlots,
    required this.captions,
    required this.audioTracks,
    required this.export,
    this.music,
  });

  /// Parses and validates. Throws [EditPlanFormatException] on any violation.
  factory EditPlan.fromJson(Map<String, dynamic> j) {
    final version = j['schemaVersion'];
    if (version != editPlanSchemaVersion) {
      throw EditPlanFormatException('Unsupported schemaVersion: $version');
    }
    try {
      final plan = EditPlan(
        title: _str(j, 'title'),
        summary: _str(j, 'summary'),
        durationSec: _num(j, 'durationSec'),
        aspectRatio: _str(j, 'aspectRatio'),
        shots: _list(j, 'shots', Shot.fromJson),
        mediaSlots: _list(j, 'mediaSlots', MediaSlot.fromJson),
        captions: _list(j, 'captions', Caption.fromJson),
        audioTracks: _list(j, 'audioTracks', AudioTrack.fromJson),
        export: ExportOptions.fromJson(j['export'] as Map<String, dynamic>),
        music: j['music'] == null
            ? null
            : MusicTrack.fromJson(j['music'] as Map<String, dynamic>),
      );
      plan._validate();
      return plan;
    } on EditPlanFormatException {
      rethrow;
    } on TypeError catch (e) {
      throw EditPlanFormatException('Malformed plan: $e');
    }
  }

  final String title;
  final String summary;
  final double durationSec;
  final String aspectRatio;
  final List<Shot> shots;
  final List<MediaSlot> mediaSlots;
  final List<Caption> captions;
  final List<AudioTrack> audioTracks;
  final ExportOptions export;
  final MusicTrack? music;

  static const _eps = 0.05;

  void _validate() {
    if (durationSec <= 0) {
      throw const EditPlanFormatException('durationSec <= 0');
    }
    if (!const {'9:16', '16:9', '1:1', '4:5'}.contains(aspectRatio)) {
      throw EditPlanFormatException('Bad aspectRatio: $aspectRatio');
    }
    if (shots.isEmpty) throw const EditPlanFormatException('No shots');

    final slotIds = <String>{};
    for (final s in mediaSlots) {
      if (!slotIds.add(s.id)) {
        throw EditPlanFormatException('Duplicate media slot id: ${s.id}');
      }
    }
    final shotIds = <String>{};
    final sorted = [...shots]..sort((a, b) => a.startSec.compareTo(b.startSec));
    for (final (i, s) in sorted.indexed) {
      if (!shotIds.add(s.id)) {
        throw EditPlanFormatException('Duplicate shot id: ${s.id}');
      }
      if (s.startSec < 0 || s.endSec <= s.startSec) {
        throw EditPlanFormatException('Shot ${s.id} has invalid time range');
      }
      if (s.endSec > durationSec + _eps) {
        throw EditPlanFormatException('Shot ${s.id} exceeds duration');
      }
      if (i > 0 && s.startSec < sorted[i - 1].endSec - _eps) {
        throw EditPlanFormatException('Shot ${s.id} overlaps previous shot');
      }
      if ((s.sourceIn != null || s.sourceOut != null) &&
          (s.sourceIn == null ||
              s.sourceOut == null ||
              s.sourceIn! < 0 ||
              s.sourceOut! <= s.sourceIn!)) {
        throw EditPlanFormatException('Shot ${s.id} has invalid source range');
      }
      if (s.mediaSlotId != null && !slotIds.contains(s.mediaSlotId)) {
        throw EditPlanFormatException(
          'Shot ${s.id} references unknown slot ${s.mediaSlotId}',
        );
      }
    }
    for (final c in captions) {
      if (c.startSec < 0 ||
          c.endSec <= c.startSec ||
          c.endSec > durationSec + _eps) {
        throw EditPlanFormatException('Caption "${c.text}" out of range');
      }
    }
    for (final a in audioTracks) {
      if (a.startSec < 0 ||
          a.endSec <= a.startSec ||
          a.endSec > durationSec + _eps) {
        throw EditPlanFormatException('Audio track out of range');
      }
    }
  }
}

String _str(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is! String || v.isEmpty) {
    throw EditPlanFormatException('Missing or invalid "$k"');
  }
  return v;
}

double _num(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is! num) throw EditPlanFormatException('Missing or invalid "$k"');
  return v.toDouble();
}

List<T> _list<T>(
  Map<String, dynamic> j,
  String k,
  T Function(Map<String, dynamic>) parse,
) {
  final v = j[k];
  if (v is! List) throw EditPlanFormatException('Missing list "$k"');
  return v.map((e) => parse(e as Map<String, dynamic>)).toList();
}
