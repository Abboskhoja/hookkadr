String timecode(double sec) {
  final s = sec < 0 ? 0 : sec;
  final m = s ~/ 60;
  final r = s - m * 60;
  return '${m.toString().padLeft(2, '0')}:${r.toStringAsFixed(1).padLeft(4, '0')}';
}

String seconds(double s) => '${s.toStringAsFixed(s % 1 == 0 ? 0 : 1)} s';
