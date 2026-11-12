import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The one summary card at the top of a screen (Design/design-system.md
/// §3.4): tint surface, small label, a big value, an optional chip beside
/// the label and an optional footer (progress bar, caption, button).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.value,
    this.valueKey,
    this.chip,
    this.footer,
  });

  final String label;
  final String value;
  final Key? valueKey;

  /// Shown at the end of the label line, e.g. a delta chip.
  final Widget? chip;

  /// Under the value: a progress bar with a caption, or a text button.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.onPrimaryContainer;
    return Container(
      padding: EdgeInsets.all(Tokens.spaceM),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Label and chip wrap under each other when space runs out.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Tokens.spaceS,
            runSpacing: Tokens.spaceXs,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: on),
              ),
              ?chip,
            ],
          ),
          SizedBox(height: Tokens.spaceXxs),
          Text(
            value,
            key: valueKey,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: on,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (footer != null) ...[SizedBox(height: Tokens.spaceS), footer!],
        ],
      ),
    );
  }
}

/// A thin progress bar with a caption (§3.5): primary, warning above 85%,
/// danger above 100% — the caption states the figures, so colour is never
/// the only signal.
class CaptionedProgress extends StatelessWidget {
  const CaptionedProgress({
    super.key,
    required this.fraction,
    required this.caption,
    required this.color,
    this.captionColor,
  });

  /// 0…1 (values above 1 draw a full bar).
  final double fraction;
  final String caption;
  final Color color;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusXs),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1).toDouble(),
            minHeight: Tokens.spaceXs + Tokens.spaceXxs,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
          ),
        ),
        SizedBox(height: Tokens.spaceXs),
        Text(
          caption,
          style: theme.textTheme.bodySmall?.copyWith(color: captionColor),
        ),
      ],
    );
  }
}
