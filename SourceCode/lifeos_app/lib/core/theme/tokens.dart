import 'package:flutter/material.dart';

/// Life domains, per features spec. Each has one accent colour used for
/// chips and accents only — never full-screen floods (UI flow §5).
enum LifeDomain { mind, money, health, people, work, soul, vault }

/// Design tokens — the single source of truth for colours and sizes.
abstract final class Tokens {
  // Domain accents (UI flow §5; Design/design-system.md §3.1). One value
  // per brightness: every light value is at least 4.5:1 on white, every
  // dark value at least 6:1 on a raised dark surface.
  static const Map<LifeDomain, Color> domainColors = {
    LifeDomain.mind: Color(0xFF5C6BC0), // indigo
    LifeDomain.money: Color(0xFF2E7D32), // green
    LifeDomain.health: Color(0xFFD32F2F), // red
    LifeDomain.people: Color(0xFF9A5B00), // amber
    LifeDomain.work: Color(0xFF1565C0), // blue
    LifeDomain.soul: Color(0xFF00796B), // teal
    LifeDomain.vault: Color(0xFF546E7A), // slate
  };

  static const Map<LifeDomain, Color> domainColorsDark = {
    LifeDomain.mind: Color(0xFF9FA8DA),
    LifeDomain.money: Color(0xFF81C784),
    LifeDomain.health: Color(0xFFEF9A9A),
    LifeDomain.people: Color(0xFFFFCC80),
    LifeDomain.work: Color(0xFF90CAF9),
    LifeDomain.soul: Color(0xFF80CBC4),
    LifeDomain.vault: Color(0xFFB0BEC5),
  };

  static Color domain(
    LifeDomain d, [
    Brightness brightness = Brightness.light,
  ]) => (brightness == Brightness.dark ? domainColorsDark : domainColors)[d]!;

  // Life Score colours: <40 red, 40–69 amber, ≥70 green. For the ring and
  // bars (3:1 against the page); the band is also named in words.
  static const Color scoreLow = Color(0xFFC62828);
  static const Color scoreMid = Color(0xFFB26A00);
  static const Color scoreHigh = Color(0xFF2E7D32);
  static const Color scoreLowDark = Color(0xFFEF6C6A);
  static const Color scoreMidDark = Color(0xFFF2B441);
  static const Color scoreHighDark = Color(0xFF66BB6A);

  static Color scoreColor(
    int score, [
    Brightness brightness = Brightness.light,
  ]) {
    final dark = brightness == Brightness.dark;
    if (score < 40) return dark ? scoreLowDark : scoreLow;
    if (score < 70) return dark ? scoreMidDark : scoreMid;
    return dark ? scoreHighDark : scoreHigh;
  }

  /// Brand seed for the Material 3 colour scheme.
  static const Color seed = Color(0xFF5C6BC0);

  // Ink and paper for marks burned into shared pages (watermark, footer):
  // printed output, so fixed, never themed.
  static const Color printPaper = Color(0xFFFFFFFF);
  static const Color printInk = Color(0xFF202020);
  static const Color printMuted = Color(0xFF5A5A5A);

  // Fonts, bundled with the app (pubspec.yaml). Inter carries Latin text
  // and all numerals; Urdu falls back to Noto Naskh Arabic.
  static const String fontFamily = 'Inter';
  static const List<String> fontFallback = ['Noto Naskh Arabic'];

  // Sizing.
  static const double minTouchTarget = 48; // dp, accessibility minimum

  /// Sheets, dialogs and the hero card in Flagship and Classic. Kept as a
  /// constant for `const` call sites; prefer [radiusL], which follows the
  /// look.
  static const double radius = 16;

  // Corner radii follow the current look: Funky is rounder.
  /// Bars, swatches, progress tracks.
  static double get radiusXs => AppRadius.current.xs;

  /// Thumbnails, calendar cells, small tiles.
  static double get radiusS => AppRadius.current.s;

  /// Cards, stat tiles, text fields, list blocks.
  static double get radiusM => AppRadius.current.m;

  /// Hero card, bottom sheets, dialogs.
  static double get radiusL => AppRadius.current.l;

  /// Chips, pills, search field, avatars.
  static const double radiusFull = 999;

  // Icons: inline with text / inside chips and buttons / rows and app bar.
  static const double iconS = 16;
  static const double iconM = 20;
  static const double iconL = 24;

  // Emoji are for content the user chose (avatars, folder symbols).
  static const double emojiS = 20;
  static const double emojiM = 24;
  static const double emojiL = 40;

  // Motion. Custom animations jump to their end state when the system's
  // reduce-motion setting is on.
  /// Press feedback, chip select, fades.
  static const Duration motionFast = Duration(milliseconds: 100);

  /// Check-off tick, expand and collapse.
  static const Duration motionBase = Duration(milliseconds: 200);

  /// Cross-fade between loading and content.
  static const Duration motionSlow = Duration(milliseconds: 300);

  /// Score ring fill.
  static const Duration motionRing = Duration(milliseconds: 600);

  // Spacing and density follow the current look (PBI-031): compact for
  // Flagship/Funky, roomy for Classic. Getters, so every screen picks up a
  // look change on its next build.
  static double get bodyFontSize => AppSpacing.current.body;

  /// 2 dp: hairline gaps (dots, stacked labels). Same in every look.
  static double get spaceXxs => 2;
  static double get spaceXs => AppSpacing.current.xs;
  static double get spaceS => AppSpacing.current.s;
  static double get spaceM => AppSpacing.current.m;
  static double get spaceL => AppSpacing.current.l;
  static double get spaceXl => AppSpacing.current.xl;

  /// The page's left/right margin: every screen lines up on it.
  static double get gutter => AppSpacing.current.gutter;

  /// Where row text starts after a 24 dp leading icon: the icon plus the
  /// gap, so indented lines align with the row's title.
  static double get leadingIndent => 24 + spaceM;

  /// List rows: one line / two lines.
  static double get rowOneLine => AppSpacing.current.rowOneLine;
  static double get rowTwoLine => AppSpacing.current.rowTwoLine;

  /// Space left at the end of scrolling lists so the floating ➕ never
  /// covers the last row (the ➕ is 56 dp plus its margin).
  static double get listEnd => AppSpacing.current.listEnd;
}

/// A look's spacing and density scale (PBI-031). All steps sit on a 4 dp
/// grid.
class AppSpacing {
  const AppSpacing({
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.gutter,
    required this.rowOneLine,
    required this.rowTwoLine,
    required this.navBar,
    required this.listEnd,
    required this.body,
    required this.secondary,
    required this.label,
  });

  /// Flagship and Funky: information-dense but aligned.
  static const compact = AppSpacing(
    xs: 4,
    s: 8,
    m: 12,
    l: 16,
    xl: 24,
    gutter: 16,
    rowOneLine: 48,
    rowTwoLine: 56,
    navBar: 64,
    listEnd: 88,
    body: 15,
    secondary: 13,
    label: 12,
  );

  /// Classic: today's roomy spacing, unchanged (large text for elders).
  static const roomy = AppSpacing(
    xs: 4,
    s: 8,
    m: 16,
    l: 24,
    xl: 32,
    gutter: 16,
    rowOneLine: 56,
    rowTwoLine: 64,
    navBar: 72,
    listEnd: 120,
    body: 16,
    secondary: 14,
    label: 12,
  );

  /// The scale in use; set by the app whenever the look changes.
  static AppSpacing current = compact;

  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double gutter;
  final double rowOneLine;
  final double rowTwoLine;
  final double navBar;
  final double listEnd;
  final double body;
  final double secondary;
  final double label;

  bool get isCompact => identical(this, compact);
}

/// A look's corner radii (Design/design-system.md §3.3).
class AppRadius {
  const AppRadius({
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
  });

  /// Flagship and Classic.
  static const standard = AppRadius(xs: 4, s: 8, m: 12, l: 16);

  /// Funky: rounder shapes.
  static const round = AppRadius(xs: 6, s: 12, m: 20, l: 24);

  /// The radii in use; set by the app whenever the look changes.
  static AppRadius current = standard;

  final double xs;
  final double s;
  final double m;
  final double l;
}
