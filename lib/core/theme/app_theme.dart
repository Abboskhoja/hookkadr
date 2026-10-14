import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'semantic_colors.dart';

/// Light, calm brand colours: clear blue for actions and focus, light
/// brown (sand → caramel) for warmth. Light theme first; the video editor
/// keeps a dark "screening room" theme so footage reads true.
abstract final class AppColors {
  static const brand = Color(0xFF2563C9); // blue, 5.2:1 on white
  static const brandPressed = Color(0xFF1A4C9E);
  static const blue = Color(0xFF2563C9);
  static const blueLight = Color(0xFF7FAAEE);
  static const sky = Color(0xFFE4EEFC);

  /// Light browns.
  static const cream = Color(0xFFFAF6F0);
  static const sand = Color(0xFFEFE3D3);
  static const peach = Color(0xFFE6D3BB); // light tan
  static const coral = Color(0xFFB98B5E); // caramel
  static const brown = Color(0xFF8A6442); // 5.0:1 on cream, for small text

  static const success = Color(0xFF3D9A6C);
  static const warning = Color(0xFFC88B2C);
  static const danger = Color(0xFFCC4B42);

  /// Hero / primary surfaces: blue light with a warm sand edge.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563C9), Color(0xFF3F7BDA), Color(0xFF6E95D9)],
  );

  /// Soft warm cards (light brown).
  static const warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7EEE2), Color(0xFFEBDCC8)],
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

  /// Navy and dark brown; used by the video editor and dark-mode phones.
  static const dark = AppPalette(
    background: Color(0xFF0F141B),
    surface: Color(0xFF19202A),
    surfaceRaised: Color(0xFF243040),
    separator: Color(0xFF3A4757),
    textPrimary: Color(0xFFF5F1EA),
    textSecondary: Color(0xFFC9BEB0),
    accent: AppColors.blueLight,
    onAccent: Color(0xFF0F141B),
    muted: Color(0xFFA89D8F),
    selected: Color(0xFF2A3546),
  );

  /// Cream background, white cards, sand raised areas, blue actions.
  static const light = AppPalette(
    background: AppColors.cream,
    surface: Colors.white,
    surfaceRaised: AppColors.sand,
    separator: Color(0xFFE6DACA),
    textPrimary: Color(0xFF1E2B3C),
    textSecondary: Color(0xFF5E5650),
    accent: AppColors.blue,
    onAccent: Colors.white,
    muted: Color(0xFF6F655C),
    selected: AppColors.sky,
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
      indicatorColor: p.selected,
      indicatorShape: const StadiumBorder(),
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
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.selected,
      side: BorderSide(color: p.separator),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: p.textPrimary, fontSize: 14),
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
      (brightness == Brightness.dark
              ? Typography.material2021().white
              : Typography.material2021().black)
          .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary),
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
