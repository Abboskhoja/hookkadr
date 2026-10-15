import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'tool_button.dart';
import '../../../core/theme/editor_tokens.dart';

/// Tools for the selected shot: icon-only (tooltip = name for long press
/// and screen readers), disabled when the action is not possible.
class ShotToolsBar extends StatelessWidget {
  const ShotToolsBar({
    super.key,
    required this.canSplit,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.canTrim,
    required this.onSplit,
    required this.onDuplicate,
    required this.onLeft,
    required this.onRight,
    required this.onTrimHead,
    required this.onEffects,
    required this.canFreeze,
    required this.onFreeze,
  });

  final bool canFreeze;
  final VoidCallback onFreeze;

  final VoidCallback onEffects;
  final bool canSplit;
  final bool canMoveLeft;
  final bool canMoveRight;
  final bool canTrim;
  final VoidCallback onSplit;
  final VoidCallback onDuplicate;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onTrimHead;

  @override
  Widget build(BuildContext context) {
    Widget tool(IconData icon, String name, bool enabled, VoidCallback onTap) =>
        ToolButton(icon: icon, label: name, onTap: enabled ? onTap : null);
    return SizedBox(
      height: EditorTokens.toolbarHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          tool(LucideIcons.scissors, 'Bo‘lish', canSplit, onSplit),
          tool(LucideIcons.wandSparkles, 'Effekt', true, onEffects),
          tool(LucideIcons.copyPlus, 'Nusxa', true, onDuplicate),
          tool(LucideIcons.chevronsRight, 'Boshini kes', canTrim, onTrimHead),
          tool(LucideIcons.snowflake, 'To‘xtatish', canFreeze, onFreeze),
          tool(LucideIcons.arrowLeft, 'Chapga', canMoveLeft, onLeft),
          tool(LucideIcons.arrowRight, 'O‘ngga', canMoveRight, onRight),
        ],
      ),
    );
  }
}
