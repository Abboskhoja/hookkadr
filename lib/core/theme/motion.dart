import 'package:flutter/widgets.dart';

/// Motion tokens (spec): short, state-explaining, no bounce.
abstract final class AppMotion {
  static const messageEnter = Duration(milliseconds: 180);
  static const assistantCardEnter = Duration(milliseconds: 200);
  static const chipSelection = Duration(milliseconds: 150);
  static const bottomSheet = Duration(milliseconds: 280);
  static const previewVersionChange = Duration(milliseconds: 220);
  static const successFeedback = Duration(milliseconds: 180);
  static const reduced = Duration(milliseconds: 100);
  static const curve = Curves.easeOut;

  /// True when the OS asks to reduce/disable animations.
  static bool reduce(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration normal) =>
      reduce(context) ? reduced : normal;
}
