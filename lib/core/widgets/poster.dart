import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/app_theme.dart';

const _hues = [18.0, 30.0, 8.0, 40.0, 24.0, 2.0];

Color shotColor(int i) =>
    HSLColor.fromAHSL(1, _hues[i % _hues.length], 0.70, 0.50).toColor();

/// Barcode-like strip: one coloured segment per shot, proportional to length.
class ShotStrip extends StatelessWidget {
  const ShotStrip({
    super.key,
    required this.durations,
    this.height = 6,
    this.selected,
  });
  final List<double> durations;
  final double height;
  final int? selected;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      child: Row(
        children: [
          for (final (i, d) in durations.indexed)
            Expanded(
              flex: (d * 100).round().clamp(1, 100000),
              child: Container(
                margin: EdgeInsets.only(
                  right: i == durations.length - 1 ? 0 : 2,
                ),
                color: selected == null || selected == i
                    ? shotColor(i)
                    : shotColor(i).withValues(alpha: 0.25),
              ),
            ),
        ],
      ),
    ),
  );
}

List<double> shotDurations(Map<String, dynamic> plan) {
  final shots = (plan['shots'] as List?) ?? const [];
  return [
    for (final s in shots.cast<Map<String, dynamic>>())
      ((s['endSec'] as num) - (s['startSec'] as num)).toDouble(),
  ];
}

class ProjectPosterCard extends StatelessWidget {
  const ProjectPosterCard({
    super.key,
    required this.title,
    required this.plan,
    required this.onTap,
    this.width,
  });
  final String title;
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final durs = shotDurations(plan);
    final total = (plan['durationSec'] as num?)?.toDouble() ?? 0;
    final tint = shotColor(0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tint.withValues(alpha: 0.38), const Color(0xFF111B27)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: AspectRatio(
          aspectRatio: 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShotStrip(durations: durs, height: 5),
              const Spacer(),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${seconds(total)} · ${durs.length} kadr · ${plan['aspectRatio'] ?? ''}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? AppColors.success : context.palette.textSecondary,
    ),
  );
}
