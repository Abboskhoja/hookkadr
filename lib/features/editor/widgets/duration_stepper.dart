import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';

/// Minus / seconds / plus control used to resize the selected shot.
class DurationStepper extends StatelessWidget {
  const DurationStepper({
    super.key,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });
  final double value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget b(IconData i, VoidCallback f) => GestureDetector(
      onTap: f,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(i, size: 16, color: p.textPrimary),
      ),
    );
    return Row(
      children: [
        b(LucideIcons.minus, onMinus),
        SizedBox(
          width: 52,
          child: Text(
            seconds(value),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        b(LucideIcons.plus, onPlus),
      ],
    );
  }
}
