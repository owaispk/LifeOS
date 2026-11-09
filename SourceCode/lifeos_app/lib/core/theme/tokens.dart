import 'package:flutter/material.dart';

/// Life domains, per features spec. Each has one accent colour used for
/// chips and accents only — never full-screen floods (UI flow §5).
enum LifeDomain { mind, money, health, people, work, soul, vault }

/// Design tokens — the single source of truth for colours and sizes.
abstract final class Tokens {
  // Domain accents (UI flow §5).
  static const Map<LifeDomain, Color> domainColors = {
    LifeDomain.mind: Color(0xFF5C6BC0), // indigo
    LifeDomain.money: Color(0xFF2E7D32), // green
    LifeDomain.health: Color(0xFFD32F2F), // red
    LifeDomain.people: Color(0xFFFFA000), // amber
    LifeDomain.work: Color(0xFF1E88E5), // blue
    LifeDomain.soul: Color(0xFF00897B), // teal
    LifeDomain.vault: Color(0xFF546E7A), // slate
  };

  static Color domain(LifeDomain d) => domainColors[d]!;

  // Life Score colours: <40 red, 40–69 amber, ≥70 green.
  static const Color scoreLow = Color(0xFFE53935);
  static const Color scoreMid = Color(0xFFFFB300);
  static const Color scoreHigh = Color(0xFF43A047);

  static Color scoreColor(int score) {
    if (score < 40) return scoreLow;
    if (score < 70) return scoreMid;
    return scoreHigh;
  }

  /// Brand seed for the Material 3 colour scheme.
  static const Color seed = Color(0xFF5C6BC0);

  // Sizing.
  static const double minTouchTarget = 48; // dp, accessibility minimum
  static const double radius = 16;

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
