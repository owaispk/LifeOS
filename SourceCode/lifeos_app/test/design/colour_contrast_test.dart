// Design system §3.1: every semantic, score and life-area colour meets its
// WCAG contrast ratio against the surfaces the real theme generates — in
// light and dark, for all three looks.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/theme/app_colors.dart';
import 'package:lifeos_app/core/theme/app_theme.dart';
import 'package:lifeos_app/core/theme/tokens.dart';
import 'package:lifeos_app/features/settings/settings_providers.dart'
    show LookTemplate;

/// WCAG 2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

const _text = 4.5;
const _graphic = 3.0;

void main() {
  for (final look in LookTemplate.values) {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light
          ? AppTheme.light(look)
          : AppTheme.dark(look);
      final scheme = theme.colorScheme;
      final c = theme.extension<AppColors>()!;
      final where = '${look.name} ${brightness.name}';
      // Page, cards, and sheets/dialogs.
      final surfaces = {
        'surface': scheme.surface,
        'surfaceContainerLow': scheme.surfaceContainerLow,
        'surfaceContainerHigh': scheme.surfaceContainerHigh,
      };

      void expectContrast(
        String name,
        Color fg,
        String on,
        Color bg,
        double min,
      ) {
        final ratio = contrast(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(min),
          reason:
              '$where: $name on $on is ${ratio.toStringAsFixed(2)}:1, '
              'needs $min:1',
        );
      }

      test('$where: the theme carries the semantic colours', () {
        expect(c.brightness, brightness);
      });

      test('$where: semantic text colours read on every surface', () {
        final roles = {
          'success': c.success,
          'warning': c.warning,
          'danger': c.danger,
          'info': c.info,
        };
        for (final role in roles.entries) {
          for (final s in surfaces.entries) {
            expectContrast(role.key, role.value, s.key, s.value, _text);
          }
        }
      });

      test('$where: text reads on its semantic container', () {
        final pairs = {
          'success': (c.onSuccessContainer, c.successContainer),
          'warning': (c.onWarningContainer, c.warningContainer),
          'danger': (c.onDangerContainer, c.dangerContainer),
          'info': (c.onInfoContainer, c.infoContainer),
        };
        for (final p in pairs.entries) {
          expectContrast(
            'on${p.key}Container',
            p.value.$1,
            '${p.key}Container',
            p.value.$2,
            _text,
          );
        }
      });

      test('$where: score colours stand out as graphics', () {
        // The ring also sits on the tinted hero card.
        final grounds = {
          ...surfaces,
          'primaryContainer': scheme.primaryContainer,
        };
        for (final score in [0, 50, 90]) {
          for (final s in grounds.entries) {
            expectContrast(
              'score $score',
              c.scoreColor(score),
              s.key,
              s.value,
              _graphic,
            );
          }
        }
      });

      test('$where: life-area accents stand out as graphics', () {
        for (final d in LifeDomain.values) {
          for (final s in surfaces.entries) {
            expectContrast(d.name, c.domain(d), s.key, s.value, _graphic);
          }
        }
      });

      test('$where: secondary text reads on every surface', () {
        for (final s in surfaces.entries) {
          expectContrast(
            'onSurfaceVariant',
            scheme.onSurfaceVariant,
            s.key,
            s.value,
            _text,
          );
        }
      });
    }
  }

  test('the type scale uses three weights and nothing below 12 sp', () {
    for (final look in LookTemplate.values) {
      final t = AppTheme.light(look).textTheme;
      final styles = [
        t.displaySmall,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ];
      for (final s in styles) {
        expect(s!.fontSize, greaterThanOrEqualTo(12), reason: look.name);
        expect(
          [FontWeight.w400, FontWeight.w500, FontWeight.w600],
          contains(s.fontWeight),
          reason: look.name,
        );
      }
    }
  });

  test('the bundled fonts are declared, present and used by the theme', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final family in [Tokens.fontFamily, ...Tokens.fontFallback]) {
      expect(pubspec, contains('family: $family'));
    }
    final assets = RegExp(r'asset: (assets/fonts/\S+\.ttf)')
        .allMatches(pubspec)
        .map((m) => m.group(1)!)
        .toList();
    expect(assets, hasLength(6));
    for (final a in assets) {
      expect(File(a).existsSync(), isTrue, reason: a);
    }
    for (final look in LookTemplate.values) {
      final body = AppTheme.light(look).textTheme.bodyLarge!;
      expect(body.fontFamily, Tokens.fontFamily);
      expect(body.fontFamilyFallback, Tokens.fontFallback);
    }
  });

  test('Urdu gets taller lines; no style has letter spacing', () {
    final en = AppTheme.light(LookTemplate.flagship).textTheme;
    final ur = AppTheme.light(
      LookTemplate.flagship,
      const Locale('ur'),
    ).textTheme;
    expect(ur.bodyLarge!.height, greaterThan(en.bodyLarge!.height!));
    expect(ur.bodyLarge!.letterSpacing, 0);
    expect(ur.labelLarge!.letterSpacing, 0);
    expect(en.bodyLarge!.letterSpacing, 0);
    expect(en.labelLarge!.letterSpacing, 0);
    expect(ur.bodyLarge!.fontSize, en.bodyLarge!.fontSize);
  });

  test('Funky is rounder; Flagship and Classic share the standard radii', () {
    expect(AppTheme.radiusFor(LookTemplate.funky), AppRadius.round);
    expect(AppTheme.radiusFor(LookTemplate.flagship), AppRadius.standard);
    expect(AppTheme.radiusFor(LookTemplate.classic), AppRadius.standard);
    expect(AppRadius.round.m, greaterThan(AppRadius.standard.m));
  });
}
