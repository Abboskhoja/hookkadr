import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared editor interaction dimensions, independent of media rendering.
abstract final class EditorTokens {
  static const palette = AppPalette(
    background: Color(0xFF101114),
    surface: Color(0xFF191B20),
    surfaceRaised: Color(0xFF242730),
    separator: Color(0xFF343842),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFFA6ADBA),
    accent: Color(0xFF6BC9FF),
    onAccent: Color(0xFF101114),
    muted: Color(0xFFA6ADBA),
    selected: Color(0xFF30343E),
  );
  static const touchTarget = 48.0;
  static const toolbarHeight = 74.0;
  static const toolWidth = 70.0;
  static const toolRadius = 14.0;
  static const panelMotion = Duration(milliseconds: 180);

  static Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : panelMotion;
}
