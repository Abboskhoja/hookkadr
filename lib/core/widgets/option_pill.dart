import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

class OptionPill extends StatelessWidget {
  const OptionPill({
    required this.icon,
    required this.label,
    required this.options,
    required this.onPick,
    required this.busy,
  });
  final IconData icon;
  final String label;
  final List<String> options;
  final ValueChanged<String> onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopupMenuButton<String>(
      enabled: !busy,
      color: p.surface,
      onSelected: onPick,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(
            value: o,
            child: Row(
              children: [
                if (ratioOf(o) != null) ...[
                  RatioGlyph(ratio: ratioOf(o)!, selected: o == label),
                  const SizedBox(width: 10),
                ],
                Expanded(child: Text(o)),
                if (o == label)
                  Icon(LucideIcons.check, size: 16, color: p.accent),
              ],
            ),
          ),
      ],
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: p.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: p.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small geometric preview of an aspect ratio (spec 8.1).
class RatioGlyph extends StatelessWidget {
  const RatioGlyph({required this.ratio, required this.selected});
  final double ratio;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const box = 22.0;
    final w = ratio >= 1 ? box : box * ratio;
    final h = ratio >= 1 ? box / ratio : box;
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: selected ? p.accent.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: selected ? p.accent : p.textSecondary,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// "What changed" card for AI edits, with Undo (spec: EditDiffCard).
double? ratioOf(String label) {
  final m = RegExp(r'^(\d+):(\d+)$').firstMatch(label);
  if (m == null) return null;
  return int.parse(m.group(1)!) / int.parse(m.group(2)!);
}
