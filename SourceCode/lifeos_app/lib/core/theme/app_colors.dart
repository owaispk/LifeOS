import 'package:flutter/material.dart';

import 'tokens.dart';

/// Colours with a fixed meaning that Material's scheme has no role for
/// (Design/design-system.md §3.1). Read with `context.colors`.
///
/// Each role has a text/icon colour, a container (a tinted background) and
/// the text colour to use on that container. Every pair is at least 4.5:1;
/// `test/design/colour_contrast_test.dart` checks them against the real
/// scheme in light and dark, for all three looks.
///
/// - danger: overdue, expired, failed, destructive actions
/// - warning: due soon, expiring, needs attention
/// - success: paid, done, renewed, on track
/// - info: neutral notices, estimates, tips
///
/// Colour is never the only signal: pair it with an icon or words.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  static const light = AppColors(
    brightness: Brightness.light,
    success: Color(0xFF1B6E3A),
    successContainer: Color(0xFFDDF3E4),
    onSuccessContainer: Color(0xFF1B6E3A),
    warning: Color(0xFF8A5300),
    warningContainer: Color(0xFFFFE9C7),
    onWarningContainer: Color(0xFF8A5300),
    danger: Color(0xFFB3261E),
    dangerContainer: Color(0xFFFCE4E2),
    onDangerContainer: Color(0xFFB3261E),
    info: Color(0xFF1E5FA8),
    infoContainer: Color(0xFFDCEBFB),
    onInfoContainer: Color(0xFF1E5FA8),
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    success: Color(0xFF7FD69B),
    successContainer: Color(0xFF0F3D22),
    onSuccessContainer: Color(0xFFBFEFCB),
    warning: Color(0xFFF2BE6B),
    warningContainer: Color(0xFF4A3000),
    onWarningContainer: Color(0xFFFFDFA8),
    danger: Color(0xFFF2B8B5),
    dangerContainer: Color(0xFF5C1A16),
    onDangerContainer: Color(0xFFFAD9D7),
    info: Color(0xFF9CC7F5),
    infoContainer: Color(0xFF0E3A63),
    onInfoContainer: Color(0xFFCFE4FB),
  );

  static AppColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  final Brightness brightness;

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color danger;
  final Color dangerContainer;
  final Color onDangerContainer;

  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  /// The Life Score band colour for the ring and bars.
  Color scoreColor(int score) => Tokens.scoreColor(score, brightness);

  /// A life area's accent: dots, chips and leading icons only.
  Color domain(LifeDomain d) => Tokens.domain(d, brightness);

  @override
  AppColors copyWith() => this;

  /// Light and dark are fixed sets, so a theme change switches at the
  /// halfway point instead of blending.
  @override
  AppColors lerp(AppColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// `context.colors.warning` — the semantic colours for the current theme.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      AppColors.of(Theme.of(this).brightness);
}
