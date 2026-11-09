import 'package:flutter/material.dart';

import '../../features/settings/settings_providers.dart' show LookTemplate;
import 'tokens.dart';

/// Material 3 light/dark themes with a 16sp body baseline.
abstract final class AppTheme {
  static ThemeData light([LookTemplate look = LookTemplate.flagship]) =>
      _build(Brightness.light, look);
  static ThemeData dark([LookTemplate look = LookTemplate.flagship]) =>
      _build(Brightness.dark, look);

  /// Funky uses a warmer seed and rounder shapes (PBI-025).
  static const funkySeed = Color(0xFFE91E63);

  static ThemeData _build(Brightness brightness, LookTemplate look) {
    final scheme = ColorScheme.fromSeed(
      seedColor: look == LookTemplate.funky ? funkySeed : Tokens.seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // Classic: roomier controls for larger text.
      visualDensity: look == LookTemplate.classic
          ? const VisualDensity(horizontal: 1, vertical: 1)
          : VisualDensity.standard,
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
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: Tokens.bodyFontSize,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: Tokens.bodyFontSize,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
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
