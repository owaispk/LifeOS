import 'package:flutter/material.dart';

/// Categorical colours for spending by category, in fixed slot order
/// (rent, fees, utilities, internet, mobile, installment, subscription).
/// Both sets were checked with the data-viz palette validator against the
/// app's surfaces: lightness band, chroma, colour-blind (CVD) separation and
/// normal-vision separation all pass. Light-mode aqua/yellow/magenta sit
/// below 3:1 contrast, so every swatch is paired with a visible name and
/// amount (the category list) — never colour alone.
const _light = [
  Color(0xFF2A78D6), // blue
  Color(0xFFEB6834), // orange
  Color(0xFF1BAF7A), // aqua
  Color(0xFFEDA100), // yellow
  Color(0xFFE87BA4), // magenta
  Color(0xFF008300), // green
  Color(0xFF6250D6), // violet
];

const _dark = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF008300),
  Color(0xFF9085E9),
];

/// Colour for a category slot; null slot ("Other", custom, uncategorised)
/// is a neutral grey from the theme.
Color categoryColor(BuildContext context, int? slot) {
  final theme = Theme.of(context);
  if (slot == null) return theme.colorScheme.outline;
  final set = theme.brightness == Brightness.dark ? _dark : _light;
  return set[slot % set.length];
}
