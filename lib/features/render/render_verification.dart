import 'dart:math' as math;

/// Facts read from the encoded file by FFprobe, never copied from the plan.
class RenderMeasurements {
  const RenderMeasurements({
    required this.isMp4,
    required this.hasVideo,
    this.width,
    this.height,
    this.durationSec,
    this.containerDurationSec,
    this.fps,
  });

  factory RenderMeasurements.fromProbe(Map<dynamic, dynamic> probe) {
    final format = probe['format'];
    final streams = probe['streams'];
    Map? video;
    if (streams is List) {
      for (final stream in streams) {
        if (stream is! Map || stream['codec_type'] != 'video') continue;
        final disposition = stream['disposition'];
        if (disposition is Map && disposition['attached_pic'] == 1) continue;
        video = stream;
        break;
      }
    }
    return RenderMeasurements(
      isMp4:
          format is Map &&
          '${format['format_name']}'.split(',').contains('mp4'),
      hasVideo: video != null,
      width: _dimension(video?['width']),
      height: _dimension(video?['height']),
      // The container can outlast a truncated video because its audio remains.
      // Check the video stream's measured duration as well as the container.
      durationSec: _positiveNumber(video?['duration']),
      containerDurationSec: format is Map
          ? _positiveNumber(format['duration'])
          : null,
      fps: parseFrameRate(video?['avg_frame_rate']),
    );
  }

  final bool isMp4;
  final bool hasVideo;
  final int? width;
  final int? height;
  final double? durationSec;
  final double? containerDurationSec;
  final double? fps;
}

class RenderVerificationIssue {
  const RenderVerificationIssue(this.code, this.message);
  final String code;
  final String message;
}

/// Verifies the artifact contract. These checks do not judge visual quality,
/// intelligibility, or whether the creative brief was satisfied.
List<RenderVerificationIssue> verifyRender({
  required RenderMeasurements measured,
  required int expectedWidth,
  required int expectedHeight,
  required double expectedDurationSec,
  required int expectedFps,
}) {
  final issues = <RenderVerificationIssue>[];
  if (!measured.isMp4) {
    issues.add(
      const RenderVerificationIssue(
        'container',
        'Eksport fayli MP4 formatida ekanini tekshirib bo‘lmadi.',
      ),
    );
  }
  if (!measured.hasVideo) {
    issues.add(
      const RenderVerificationIssue(
        'video_stream',
        'Eksport faylida video oqimi topilmadi.',
      ),
    );
    return issues;
  }
  if (measured.width != expectedWidth || measured.height != expectedHeight) {
    issues.add(
      RenderVerificationIssue(
        'dimensions',
        'Eksport o‘lchami ${measured.width ?? '?'}×${measured.height ?? '?'}; '
            'kutilgan o‘lcham $expectedWidth×$expectedHeight.',
      ),
    );
  }
  // Two frames plus small container rounding are harmless; an unmeasured or
  // materially truncated stream must not be reported as a finished export.
  final durationTolerance = math.max(0.15, 2 / expectedFps);
  final duration = measured.durationSec;
  final containerDuration = measured.containerDurationSec;
  if (duration == null ||
      !duration.isFinite ||
      duration <= 0 ||
      (duration - expectedDurationSec).abs() > durationTolerance ||
      containerDuration == null ||
      !containerDuration.isFinite ||
      containerDuration <= 0 ||
      (containerDuration - expectedDurationSec).abs() > durationTolerance) {
    issues.add(
      RenderVerificationIssue(
        'duration',
        'Eksport davomiyligi rejaga mos emas yoki o‘lchanmadi '
            '(kutilgan: ${expectedDurationSec.toStringAsFixed(2)} s).',
      ),
    );
  }
  final fps = measured.fps;
  if (fps == null || !fps.isFinite || (fps - expectedFps).abs() > 0.1) {
    issues.add(
      RenderVerificationIssue(
        'frame_rate',
        'Eksport kadr tezligi tekshiruvdan o‘tmadi '
            '(kutilgan: $expectedFps FPS).',
      ),
    );
  }
  return issues;
}

/// FFprobe expresses average frame rates as rationals such as `30000/1001`.
double? parseFrameRate(Object? value) {
  if (value is num) return _positiveNumber(value);
  if (value is! String) return null;
  final parts = value.split('/');
  if (parts.length == 1) return _positiveNumber(value);
  if (parts.length != 2) return null;
  final numerator = _positiveNumber(parts[0]);
  final denominator = _positiveNumber(parts[1]);
  return numerator == null || denominator == null
      ? null
      : _positiveNumber(numerator / denominator);
}

double? _positiveNumber(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number != null && number.isFinite && number > 0 ? number : null;
}

int? _dimension(Object? value) {
  final number = _positiveNumber(value);
  return number != null && number == number.roundToDouble()
      ? number.toInt()
      : null;
}
