import 'package:flutter/material.dart';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/theme/tokens.dart';
import '../domain/money_rules.dart';
import 'category_colors.dart';

/// Spending by category: a thin segmented bar (one whole split into parts)
/// above a ranked list whose rows carry each part's swatch, name, amount and
/// share — the list is the legend and the table view.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({
    super.key,
    required this.slices,
    required this.totalMinor,
  });

  final List<CategorySlice> slices;
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final description = [
      for (final s in slices)
        l.mnBreakdownItem(
          s.name,
          Money.format(s.amountMinor),
          '${s.sharePercent(totalMinor)}',
        ),
    ].join('; ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: l.mnBreakdownSemantics(description),
          excludeSemantics: true,
          child: SizedBox(
            key: const ValueKey('category-bar'),
            height: 8,
            child: CustomPaint(
              painter: _SegmentedBarPainter(
                values: [for (final s in slices) s.amountMinor],
                colors: [
                  for (final s in slices) categoryColor(context, s.colorSlot),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: Tokens.spaceM),
        for (final s in slices)
          Padding(
            key: ValueKey('category-row-${s.categoryId ?? 'none'}'),
            padding: EdgeInsets.symmetric(vertical: Tokens.spaceXs),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: categoryColor(context, s.colorSlot),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(width: Tokens.spaceS),
                Text(s.icon),
                SizedBox(width: Tokens.spaceS),
                Expanded(child: Text(s.name, style: theme.textTheme.bodyLarge)),
                Text(
                  Money.format(s.amountMinor),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${s.sharePercent(totalMinor)}%',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Thin segmented bar: widths ∝ values, 2px surface gap between parts,
/// fully rounded outer ends, a zero part draws nothing.
class _SegmentedBarPainter extends CustomPainter {
  _SegmentedBarPainter({required this.values, required this.colors});

  final List<int> values;
  final List<Color> colors;

  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final parts = [
      for (var i = 0; i < values.length; i++)
        if (values[i] > 0) (values[i], colors[i]),
    ];
    final total = parts.fold<int>(0, (s, p) => s + p.$1);
    if (total == 0) return;

    final usable = size.width - _gap * (parts.length - 1);
    final radius = Radius.circular(size.height / 2);
    // Clip to a pill so only the outer ends are rounded.
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    var x = 0.0;
    for (var i = 0; i < parts.length; i++) {
      final w = usable * parts[i].$1 / total;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, w, size.height),
        Paint()..color = parts[i].$2,
      );
      x += w + _gap;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SegmentedBarPainter old) =>
      old.values != values || old.colors != colors;
}
