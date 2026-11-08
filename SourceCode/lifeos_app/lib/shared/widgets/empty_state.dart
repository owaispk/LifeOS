import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The standard "never a blank screen" empty state (UI flow §5):
/// an illustration, a short message and at most one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.inList = false,
  });

  final String emoji;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Set when the empty state sits inside a scrolling list: it then sizes
  /// to its content instead of centring itself in the available height.
  final bool inList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const padding = EdgeInsets.all(Tokens.spaceXl);
    final content = _content(theme);
    if (inList) return Padding(padding: padding, child: content);
    return Center(
      child: SingleChildScrollView(padding: padding, child: content),
    );
  }

  Widget _content(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(emoji, style: const TextStyle(fontSize: 64)),
        ),
        const SizedBox(height: Tokens.spaceM),
        Text(
          title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Tokens.spaceS),
        Text(
          message,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: Tokens.spaceL),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, Tokens.minTouchTarget),
            ),
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
