import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../shared/widgets/empty_state.dart';
import 'home_screen.dart' show attentionProvider;
import 'ui/attention_tile.dart';

/// 1.2 Needs Attention — the full list (PBI-021 "See all").
class AttentionScreen extends ConsumerWidget {
  const AttentionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(attentionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.hmNeedsAttention)),
      body: items.isEmpty
          ? EmptyState(
              emoji: '✅',
              title: context.l10n.hmNothingUrgent,
              message: context.l10n.hmNothingUrgentBody,
            )
          : ListView(
              key: const ValueKey('attention-list'),
              padding: const EdgeInsets.only(bottom: 120),
              children: [for (final i in items) AttentionTile(item: i)],
            ),
    );
  }
}
