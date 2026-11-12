import 'package:flutter/material.dart';

import '../../features/settings/settings_providers.dart' show LookTemplate;
import 'app_colors.dart';
import 'tokens.dart';

/// Material 3 light/dark themes per look (PBI-025). Flagship and Funky
/// are compact and dense; Classic keeps roomy spacing (PBI-031).
///
/// The type scale, shapes and component styles follow
/// Design/design-system.md §3. Screens style through the theme: no colour,
/// size or radius literals in feature code.
abstract final class AppTheme {
  static ThemeData light([
    LookTemplate look = LookTemplate.flagship,
    Locale? locale,
  ]) => _build(Brightness.light, look, locale);
  static ThemeData dark([
    LookTemplate look = LookTemplate.flagship,
    Locale? locale,
  ]) => _build(Brightness.dark, look, locale);

  /// Funky uses a warmer seed and rounder shapes (PBI-025).
  static const funkySeed = Color(0xFFE91E63);

  /// The spacing scale for [look] (PBI-031).
  static AppSpacing spacingFor(LookTemplate look) =>
      look == LookTemplate.classic ? AppSpacing.roomy : AppSpacing.compact;

  /// The corner radii for [look].
  static AppRadius radiusFor(LookTemplate look) =>
      look == LookTemplate.funky ? AppRadius.round : AppRadius.standard;

  static ThemeData _build(
    Brightness brightness,
    LookTemplate look,
    Locale? locale,
  ) {
    final sp = spacingFor(look);
    final r = radiusFor(look);
    final scheme = ColorScheme.fromSeed(
      seedColor: look == LookTemplate.funky ? funkySeed : Tokens.seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: Tokens.fontFamily,
      fontFamilyFallback: Tokens.fontFallback,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // Classic: roomier controls for larger text.
      // Flagship/Funky: slightly tighter controls; Classic: roomier.
      visualDensity: look == LookTemplate.classic
          ? const VisualDensity(horizontal: 1, vertical: 1)
          // Vertical stays 0: a negative value would shrink buttons with
          // a 48 dp minimum below 48 (found by the tap-target test). Rows
          // get compact heights from the list-tile theme instead.
          : const VisualDensity(horizontal: -1, vertical: 0),
    );
    final text = _textTheme(
      base.textTheme,
      sp,
      urdu: locale?.languageCode == 'ur',
    );
    final shapeM = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r.m),
    );
    final shapeL = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r.l),
    );
    // Buttons are at least 48 dp tall: the visible shape is the tap area.
    const buttonSize = Size(64, Tokens.minTouchTarget);
    return base.copyWith(
      textTheme: text,
      extensions: [AppColors.of(brightness)],
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      // One list-row rhythm everywhere; content on the page gutter.
      listTileTheme: ListTileThemeData(
        minTileHeight: sp.rowOneLine,
        minVerticalPadding: sp.isCompact ? 6 : 8,
        contentPadding: EdgeInsets.symmetric(horizontal: sp.gutter),
        horizontalTitleGap: sp.isCompact ? 12 : 16,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      // Flat: depth comes from the surface tone, not a shadow.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: shapeM,
        margin: EdgeInsets.symmetric(horizontal: sp.gutter, vertical: sp.xs),
      ),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonSize,
          textStyle: text.labelLarge,
        ),
      ),
      // One field style everywhere: outlined.
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(r.m)),
      ),
      dialogTheme: DialogThemeData(
        shape: shapeL,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: sp.navBar,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.secondaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(r.l)),
        ),
      ),
    );
  }

  /// The type scale (design system §3.2): three weights (400, 500, 600),
  /// sizes per look. Body, secondary and label sizes are PBI-031's.
  ///
  /// Urdu gets taller lines. No style has letter spacing.
  static TextTheme _textTheme(
    TextTheme base,
    AppSpacing sp, {
    required bool urdu,
  }) {
    final compact = sp.isCompact;
    TextStyle? style(
      TextStyle? from, {
      required double size,
      required double line,
      required FontWeight weight,
      bool tabular = false,
    }) => from?.copyWith(
      fontSize: size,
      height: line / size * (urdu ? 1.2 : 1),
      fontWeight: weight,
      // Inter is drawn for zero tracking at text sizes (Material's
      // defaults were tuned for Roboto), and Urdu's joined letters must
      // not be spaced apart.
      letterSpacing: 0,
      // Amounts and times line up in columns.
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
    const regular = FontWeight.w400;
    const medium = FontWeight.w500;
    const semibold = FontWeight.w600;
    final bodyLine = compact ? 22.0 : 24.0;
    final smallLine = compact ? 18.0 : 20.0;
    return base.copyWith(
      // Hero number: month total, score.
      displaySmall: style(
        base.displaySmall,
        size: compact ? 28 : 32,
        line: compact ? 34 : 40,
        weight: semibold,
        tabular: true,
      ),
      // Editable title on a detail screen.
      headlineSmall: style(
        base.headlineSmall,
        size: compact ? 22 : 24,
        line: compact ? 28 : 32,
        weight: semibold,
      ),
      // App bar, sheet and dialog titles.
      titleLarge: style(
        base.titleLarge,
        size: compact ? 20 : 22,
        line: compact ? 26 : 28,
        weight: semibold,
      ),
      // Card titles, stat-tile values.
      titleMedium: style(
        base.titleMedium,
        size: compact ? 16 : 18,
        line: compact ? 22 : 24,
        weight: semibold,
      ),
      // Section headers.
      titleSmall: style(
        base.titleSmall,
        size: compact ? 13 : 14,
        line: smallLine,
        weight: semibold,
      ),
      bodyLarge: style(
        base.bodyLarge,
        size: sp.body,
        line: bodyLine,
        weight: regular,
      ),
      bodyMedium: style(
        base.bodyMedium,
        size: sp.body,
        line: bodyLine,
        weight: regular,
      ),
      bodySmall: style(
        base.bodySmall,
        size: sp.secondary,
        line: smallLine,
        weight: regular,
      ),
      // Buttons.
      labelLarge: style(
        base.labelLarge,
        size: compact ? 14 : 15,
        line: 20,
        weight: semibold,
      ),
      // Trailing values: amounts, times, counts.
      labelMedium: style(
        base.labelMedium,
        size: sp.secondary,
        line: smallLine,
        weight: medium,
        tabular: true,
      ),
      // Chips, bottom-bar labels, badges.
      labelSmall: style(
        base.labelSmall,
        size: sp.label,
        line: 16,
        weight: medium,
      ),
    );
  }
}
