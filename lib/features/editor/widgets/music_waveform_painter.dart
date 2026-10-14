import 'package:flutter/material.dart';

/// Music waveform from the cached loudness envelope (computed once when the
/// song is added, never per frame).
class MusicWaveformPainter extends CustomPainter {
  MusicWaveformPainter({
    required this.peaks,
    required this.offsetSec,
    required this.pps,
    required this.color,
  });
  final List<double> peaks;
  final double offsetSec;
  final double pps;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = (0.1 * pps * 0.6).clamp(1.0, 6.0);
    final mid = size.height / 2;
    for (var i = 0; i < peaks.length; i++) {
      final x = (i * 0.1 - offsetSec) * pps;
      if (x < 0) continue;
      if (x > size.width) break;
      final h = peaks[i] * (size.height - 6) / 2;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), paint);
    }
  }

  @override
  bool shouldRepaint(MusicWaveformPainter old) =>
      old.peaks != peaks || old.pps != pps || old.offsetSec != offsetSec;
}
