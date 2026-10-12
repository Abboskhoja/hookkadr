import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'semantic_colors.dart';

/// Colors inspired by the clapperboard logo: blue light and warm amber.
abstract final class AppColors {
  static const brand = Color(0xFFFFAA58);
  static const brandPressed = Color(0xFFA64B12);
  static const peach = Color(0xFFFFD4A0);
  static const coral = Color(0xFFFF9950);
  static const blue = Color(0xFF1673B8);
  static const blueLight = Color(0xFF6BC9FF);
  static const success = Color(0xFF78B99A);
  static const warning = Color(0xFFE4B76B);
  static const danger = Color(0xFFE1847D);

  /// Blue-to-amber lighting from the logo's play symbol.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, blueLight, peach, coral],
  );
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.separator,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.muted,
    required this.selected,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color separator;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  /// Text/icon colour on top of [accent] (WCAG AA checked).
  final Color onAccent;
  final Color muted;

  /// Background of a selected icon / row.
  final Color selected;

  static const dark = AppPalette(
    background: Colors.black,
    surface: Color(0xFF111B27),
    surfaceRaised: Color(0xFF1C2B3C),
    separator: Color(0xFF35485E),
    textPrimary: Color(0xFFF6F8FC),
    textSecondary: Color(0xFFB4C4D6),
    accent: AppColors.brand,
    onAccent: Color(0xFF111B27),
    muted: Color(0xFF95A8BC),
    selected: Color(0xFF38271C),
  );

  static const light = AppPalette(
    background: Colors.white,
    surface: Color(0xFFF3F7FC),
    surfaceRaised: Color(0xFFE6EEF7),
    separator: Color(0xFFCEDAE8),
    textPrimary: Color(0xFF152538),
    textSecondary: Color(0xFF50647B),
    accent: AppColors.brandPressed,
    onAccent: Colors.white,
    muted: Color(0xFF536A82),
    selected: Color(0xFFFFEAD6),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      other is AppPalette ? (t < 0.5 ? this : other) : this;
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.onAccent,
        secondary: brightness == Brightness.dark
            ? AppColors.blueLight
            : AppColors.blue,
        onSecondary: brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: AppColors.danger,
        outlineVariant: p.separator,
      );
  const radius = BorderRadius.all(Radius.circular(14));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    extensions: [
      p,
      brightness == Brightness.dark
          ? HookkadrSemanticColors.dark
          : HookkadrSemanticColors.light,
    ],
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: p.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: p.separator,
      space: 1,
      thickness: 0.5,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.accent : p.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 25,
          color: s.contains(WidgetState.selected) ? p.accent : p.textSecondary,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: p.textPrimary,
        side: BorderSide(color: p.separator),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.all(16),
      border: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: p.textSecondary),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: p.accent,
      inactiveTrackColor: p.surfaceRaised,
      thumbColor: Colors.white,
      overlayShape: SliderComponentShape.noOverlay,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    textTheme: GoogleFonts.interTextTheme(
      Typography.material2021().black.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
    ),
  );
}

abstract final class AppText {
  /// Display 30–34 px SemiBold (spec 3.3).
  static TextStyle display(BuildContext c, {double size = 32}) =>
      GoogleFonts.inter(
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: c.palette.textPrimary,
      );

  static TextStyle largeTitle(BuildContext c) => TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: c.palette.textPrimary,
  );
  static TextStyle title(BuildContext c) => TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    color: c.palette.textPrimary,
  );
  static TextStyle body(BuildContext c) =>
      TextStyle(fontSize: 16, height: 1.35, color: c.palette.textPrimary);
  static TextStyle caption(BuildContext c) =>
      TextStyle(fontSize: 13, color: c.palette.textSecondary);
  static TextStyle micro(BuildContext c) =>
      TextStyle(fontSize: 11.5, color: c.palette.muted);
}
