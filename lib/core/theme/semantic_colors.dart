import 'package:flutter/material.dart';

import 'app_theme.dart';

/// HOOKKADR semantic tokens on top of [AppPalette]. Screens never use raw
/// HEX values; they read roles from here.
///
/// Rules: orange = primary actions only; blue/cyan = secondary actions,
/// focus, links. Cyan/orange/peach are never small text on white.
@immutable
class HookkadrSemanticColors extends ThemeExtension<HookkadrSemanticColors> {
  const HookkadrSemanticColors({
    required this.actionPrimary,
    required this.actionPrimaryForeground,
    required this.actionSecondary,
    required this.borderSubtle,
    required this.borderStrong,
    required this.focusRing,
    required this.videoStage,
    required this.videoChrome,
    required this.timelineTrack,
    required this.timelinePlayhead,
    required this.scrim,
  });

  final Color actionPrimary;
  final Color actionPrimaryForeground;
  final Color actionSecondary;

  /// Decorative dividers only.
  final Color borderSubtle;

  /// Focus, selection and control outlines (≥3:1 against the background).
  final Color borderStrong;
  final Color focusRing;

  /// Neutral stage behind video; chrome on top of video.
  final Color videoStage;
  final Color videoChrome;
  final Color timelineTrack;
  final Color timelinePlayhead;
  final Color scrim;

  static final light = HookkadrSemanticColors(
    actionPrimary: AppPalette.light.accent, // #A64B12, 5.8:1 with white
    actionPrimaryForeground: AppPalette.light.onAccent,
    actionSecondary: AppColors.blue, // #1673B8, 5.0:1 on white
    borderSubtle: AppPalette.light.separator, // #CEDAE8 (decorative)
    borderStrong: const Color(0xFF7A90A8), // 3.3:1 on white
    focusRing: AppColors.blue,
    videoStage: Colors.black,
    videoChrome: Colors.white,
    timelineTrack: AppPalette.light.surfaceRaised,
    timelinePlayhead: AppPalette.light.textPrimary,
    scrim: const Color(0x99000000),
  );

  static final dark = HookkadrSemanticColors(
    actionPrimary: AppPalette.dark.accent, // #FFAA58, 9.2:1 with #111B27
    actionPrimaryForeground: AppPalette.dark.onAccent,
    actionSecondary: AppColors.blueLight, // #6BC9FF
    borderSubtle: AppPalette.dark.separator, // #35485E (decorative)
    borderStrong: const Color(0xFF607890), // 4.6:1 on black
    focusRing: AppColors.blueLight,
    videoStage: Colors.black,
    videoChrome: Colors.white,
    timelineTrack: AppPalette.dark.surfaceRaised,
    timelinePlayhead: Colors.white,
    scrim: const Color(0xB3000000),
  );

  @override
  HookkadrSemanticColors copyWith() => this;

  @override
  HookkadrSemanticColors lerp(
    ThemeExtension<HookkadrSemanticColors>? other,
    double t,
  ) => other is HookkadrSemanticColors ? (t < 0.5 ? this : other) : this;
}

extension HookkadrSemanticContext on BuildContext {
  HookkadrSemanticColors get hk =>
      Theme.of(this).extension<HookkadrSemanticColors>()!;
}

/// WCAG relative-luminance contrast ratio (used by tests and audits).
double contrastRatio(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : ((v + 0.055) / 1.055) *
              ((v + 0.055) / 1.055) *
              _pow04((v + 0.055) / 1.055);
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a);
  final lb = lum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

// x^0.4 so that x^2 * x^0.4 = x^2.4 without dart:math in the hot path.
double _pow04(double x) {
  if (x <= 0) return 0;
  // exp(0.4 * ln x) via a few Newton-free series is overkill; use dart:core.
  return _exp(0.4 * _ln(x));
}

double _ln(double x) {
  // Natural log via atanh series, accurate for 0 < x <= ~4 (inputs are 0..1).
  final y = (x - 1) / (x + 1);
  final y2 = y * y;
  var term = y;
  var sum = 0.0;
  for (var n = 1; n < 60; n += 2) {
    sum += term / n;
    term *= y2;
  }
  return 2 * sum;
}

double _exp(double x) {
  var term = 1.0;
  var sum = 1.0;
  for (var n = 1; n < 40; n++) {
    term *= x / n;
    sum += term;
  }
  return sum;
}
