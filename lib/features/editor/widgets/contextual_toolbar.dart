import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A single stable dock; selecting a clip replaces the general tool set.
class ContextualToolbar extends StatelessWidget {
  const ContextualToolbar({
    super.key,
    required this.selected,
    required this.onDismiss,
    required this.generalTools,
    required this.clipTools,
  });

  final bool selected;
  final VoidCallback onDismiss;
  final Widget generalTools, clipTools;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: Border(top: BorderSide(color: context.palette.separator)),
    ),
    child: Row(
      children: [
        if (selected)
          IconButton(
            tooltip: 'Tanlovni yopish',
            onPressed: onDismiss,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        Expanded(child: selected ? clipTools : generalTools),
      ],
    ),
  );
}
