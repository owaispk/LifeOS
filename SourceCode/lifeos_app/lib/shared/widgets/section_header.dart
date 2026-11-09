import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Upper-case section label for settings-style lists (Settings, My Profile).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Tokens.gutter,
        Tokens.spaceL,
        Tokens.gutter,
        Tokens.spaceXs,
      ),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
