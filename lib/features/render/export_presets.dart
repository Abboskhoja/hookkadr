/// HOOKKADR "Balanced" export presets. These are product engineering
/// targets, not provider generation limits; keep tuning them here only.
class ExportPreset {
  const ExportPreset({
    required this.label,
    required this.shortSide,
    required this.videoBitrate,
    required this.audioBitrate,
  });

  final String label; // 360p, 720p, 1080p, 4K
  final int shortSide;
  final int videoBitrate; // bits per second
  final int audioBitrate; // bits per second

  static const all = [
    ExportPreset(
      label: '360p',
      shortSide: 360,
      videoBitrate: 1200000,
      audioBitrate: 128000,
    ),
    ExportPreset(
      label: '720p',
      shortSide: 720,
      videoBitrate: 5000000,
      audioBitrate: 160000,
    ),
    ExportPreset(
      label: '1080p',
      shortSide: 1080,
      videoBitrate: 10000000,
      audioBitrate: 192000,
    ),
    ExportPreset(
      label: '4K',
      shortSide: 2160,
      videoBitrate: 35000000,
      audioBitrate: 256000,
    ),
  ];

  static ExportPreset of(String resolution) =>
      all.firstWhere((p) => p.label == resolution, orElse: () => all[2]);

  String get uiName => switch (label) {
    '360p' => 'Compact',
    '720p' => 'HD',
    '1080p' => 'Full HD',
    _ => 'Ultra HD',
  };
}

/// estimated_bytes = (video_bps + audio_bps) × seconds / 8
abstract final class FileSizeEstimator {
  static int estimateBytes(String resolution, double seconds) {
    final p = ExportPreset.of(resolution);
    return ((p.videoBitrate + p.audioBitrate) * seconds / 8).round();
  }

  /// Decimal units (1 MB = 1 000 000 bytes), as phones show file sizes.
  static String formatBytes(int bytes) {
    final mb = bytes / 1e6;
    if (mb >= 1000) return '${(mb / 1000).toStringAsFixed(1)} GB';
    return mb >= 10
        ? '${mb.toStringAsFixed(0)} MB'
        : '${mb.toStringAsFixed(1)} MB';
  }

  /// Always labelled as an estimate in the UI.
  static String estimateLabel(String resolution, double seconds) =>
      '≈${formatBytes(estimateBytes(resolution, seconds))}';
}
