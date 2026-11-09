import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('Needs attention')),
      body: items.isEmpty
          ? const EmptyState(
              emoji: '✅',
              title: 'Nothing urgent',
              message: 'Payments due soon and expiring documents show here.',
            )
          : ListView(
              key: const ValueKey('attention-list'),
              padding: const EdgeInsets.only(bottom: 120),
              children: [for (final i in items) AttentionTile(item: i)],
            ),
    );
  }
}
