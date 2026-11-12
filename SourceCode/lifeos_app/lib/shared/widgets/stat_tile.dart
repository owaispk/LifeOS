import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// A small figure with a grey label above it (Design/design-system.md
/// §3.4). Used in a [StatTileRow] of two or three.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Tokens.spaceS,
        vertical: Tokens.spaceS,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: Tokens.spaceXxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Equal-width tiles `spaceS` apart; a column instead when the text is
/// large (above 1.3×) or the row is narrower than 300 dp. A 360 dp phone
/// (328 dp inside the gutters) keeps its three tiles side by side.
class StatTileRow extends StatelessWidget {
  const StatTileRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  static const _minRowWidth = 300.0;
  static const _maxRowScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, box) {
        if (scale > _maxRowScale || box.maxWidth < _minRowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) SizedBox(height: Tokens.spaceS),
                tiles[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) SizedBox(width: Tokens.spaceS),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}
