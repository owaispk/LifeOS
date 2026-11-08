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
  static const double bodyFontSize = 16; // sp, large readable default
  static const double spaceXs = 4;
  static const double spaceS = 8;
  static const double spaceM = 16;
  static const double spaceL = 24;
  static const double spaceXl = 32;
  static const double radius = 16;
}
