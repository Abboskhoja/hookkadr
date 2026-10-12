import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';

import '../montage/application/montage_service.dart';

/// Measured facts about one clip (offline, FFmpeg). Never guessed.
class ClipFacts {
  const ClipFacts({
    required this.id,
    required this.durationSec,
    this.sceneCuts = const [],
    this.silences = const [],
    this.hasAudio = false,
  });

  final String id;
  final double durationSec;

  /// Timestamps (s) where the picture changes a lot.
  final List<double> sceneCuts;

  /// Quiet stretches (s) — candidates for "remove pauses".
  final List<({double start, double end})> silences;
  final bool hasAudio;

  /// Short text the AI planner receives as measured data.
  String get hint {
    final cuts = sceneCuts.map((c) => c.toStringAsFixed(1)).join(', ');
    final quiet = silences
        .map((s) => '${s.start.toStringAsFixed(1)}–${s.end.toStringAsFixed(1)}')
        .join(', ');
    return 'Measured: duration ${durationSec.toStringAsFixed(1)} s; '
        'scene cuts at [${cuts.isEmpty ? 'none' : cuts}] s; '
        'silent pauses [${quiet.isEmpty ? 'none' : quiet}] s.';
  }
}

/// Parses `showinfo` output for scene-cut timestamps.
List<double> parseSceneCuts(String log) {
  final re = RegExp(r'pts_time:\s*([0-9]+(?:\.[0-9]+)?)');
  final out = <double>[];
  for (final m in re.allMatches(log)) {
    final t = double.parse(m.group(1)!);
    if (out.isEmpty || (t - out.last).abs() > 0.3) out.add(t);
  }
  return out;
}

/// Parses `silencedetect` output. An open silence runs to [durationSec].
List<({double start, double end})> parseSilences(
  String log,
  double durationSec,
) {
  final out = <({double start, double end})>[];
  double? open;
  final re = RegExp(r'silence_(start|end):\s*(-?[0-9]+(?:\.[0-9]+)?)');
  for (final m in re.allMatches(log)) {
    final v = double.parse(m.group(2)!).clamp(0.0, durationSec).toDouble();
    if (m.group(1) == 'start') {
      open = v;
    } else if (open != null) {
      if (v > open) out.add((start: open, end: v));
      open = null;
    }
  }
  if (open != null && durationSec > open) {
    out.add((start: open, end: durationSec));
  }
  return out;
}

class MediaAnalyzer implements ClipAnalyzer {
  @override
  /// One fast low-resolution pass per clip: scene changes + silences.
  Future<ClipFacts> analyze(String id, String path) async {
    final info = (await FFprobeKit.getMediaInformation(path))
        .getMediaInformation();
    final duration = double.tryParse(info?.getDuration() ?? '') ?? 0;
    final streams = info?.getStreams() ?? const [];
    final hasVideo = streams.any((s) => s.getType() == 'video');
    final hasAudio = streams.any((s) => s.getType() == 'audio');
    if (!hasVideo || duration <= 0) {
      return ClipFacts(id: id, durationSec: duration, hasAudio: hasAudio);
    }
    final graph = StringBuffer(
      "[0:v]scale=160:-2,select='gt(scene\\,0.32)',showinfo[v]",
    );
    if (hasAudio) graph.write(';[0:a]silencedetect=n=-35dB:d=0.45[a]');
    final args = [
      '-hide_banner',
      '-i',
      path,
      '-filter_complex',
      graph.toString(),
      '-map',
      '[v]',
      if (hasAudio) ...['-map', '[a]'],
      '-f',
      'null',
      '-',
    ];
    final session = await FFmpegKit.executeWithArguments(args);
    final log = await session.getAllLogsAsString() ?? '';
    return ClipFacts(
      id: id,
      durationSec: duration,
      sceneCuts: parseSceneCuts(log),
      silences: hasAudio ? parseSilences(log, duration) : const [],
      hasAudio: hasAudio,
    );
  }
}
