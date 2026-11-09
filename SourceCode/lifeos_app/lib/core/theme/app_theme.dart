import 'package:flutter/material.dart';

import '../../features/settings/settings_providers.dart' show LookTemplate;
import 'tokens.dart';

/// Material 3 light/dark themes per look (PBI-025). Flagship and Funky
/// are compact and dense; Classic keeps roomy spacing (PBI-031).
abstract final class AppTheme {
  static ThemeData light([LookTemplate look = LookTemplate.flagship]) =>
      _build(Brightness.light, look);
  static ThemeData dark([LookTemplate look = LookTemplate.flagship]) =>
      _build(Brightness.dark, look);

  /// Funky uses a warmer seed and rounder shapes (PBI-025).
  static const funkySeed = Color(0xFFE91E63);

  /// The spacing scale for [look] (PBI-031).
  static AppSpacing spacingFor(LookTemplate look) =>
      look == LookTemplate.classic ? AppSpacing.roomy : AppSpacing.compact;

  static ThemeData _build(Brightness brightness, LookTemplate look) {
    final sp = spacingFor(look);
    final scheme = ColorScheme.fromSeed(
      seedColor: look == LookTemplate.funky ? funkySeed : Tokens.seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // Classic: roomier controls for larger text.
      // Flagship/Funky: slightly tighter controls; Classic: roomier.
      visualDensity: look == LookTemplate.classic
          ? const VisualDensity(horizontal: 1, vertical: 1)
          // Vertical stays 0: a negative value would shrink buttons with
          // a 48 dp minimum below 48 (found by the tap-target test). Rows
          // get compact heights from the list-tile theme instead.
          : const VisualDensity(horizontal: -1, vertical: 0),
      cardTheme: look == LookTemplate.funky
          ? const CardThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            )
          : null,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: sp.body),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: sp.body),
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: sp.secondary),
        labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: sp.label),
        // Amounts and times line up in columns.
        labelMedium: base.textTheme.labelMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      // One list-row rhythm everywhere; content on the page gutter.
      listTileTheme: ListTileThemeData(
        minTileHeight: sp.rowOneLine,
        minVerticalPadding: sp.isCompact ? 6 : 8,
        contentPadding: EdgeInsets.symmetric(horizontal: sp.gutter),
        horizontalTitleGap: sp.isCompact ? 12 : 16,
        subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
          fontSize: sp.secondary,
          color: scheme.onSurfaceVariant,
        ),
      ),
      cardTheme: (base.cardTheme).copyWith(
        margin: EdgeInsets.symmetric(horizontal: sp.gutter, vertical: sp.xs),
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
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Tokens.radius),
          ),
        ),
      ),
    );
  }
}
