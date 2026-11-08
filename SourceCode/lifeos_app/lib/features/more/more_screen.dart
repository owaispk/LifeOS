import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/tab_scaffold.dart';

/// 5. MORE — ATC rules, settings, P1 domains. Real content in PBI-017/025.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabScaffold(
      title: 'More',
      body: EmptyState(
        emoji: '⋯',
        title: 'More is on the way',
        message: 'Auto-task rules, settings and more life areas will live here.',
      ),
    );
  }
}
