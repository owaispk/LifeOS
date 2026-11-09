import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/theme/tokens.dart';
import '../../money/ui/paid_sheet.dart';
import '../domain/attention.dart';

/// One Needs Attention row. Payments: swipe right = paid (the completion
/// chain, PBI-016); tap opens the task. Documents: tap opens the viewer.
class AttentionTile extends ConsumerWidget {
  const AttentionTile({super.key, required this.item});
  final AttentionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = item.payment;
    final amount = p?.amountMinor == null
        ? null
        : Money.format(p!.amountMinor!);
    final tile = ListTile(
      key: ValueKey('attention-${item.id}'),
      leading: Semantics(
        label: item.urgent ? 'Urgent' : 'Soon',
        excludeSemantics: true,
        child: Text(
          item.urgent ? '🔴' : '🟠',
          style: const TextStyle(fontSize: 18),
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [item.when, ?amount].join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: item.daysLeft < 0
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        item.kind == AttentionKind.payment
            ? Icons.payments_outlined
            : Icons.description_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () {
        if (item.kind == AttentionKind.document) {
          context.push('/doc/${item.id}');
        } else if (p!.taskId != null) {
          context.go('/tasks/task/${p.taskId}');
        } else {
          payWithChain(context, ref, p);
        }
      },
    );
    if (p == null) return tile;
    return Dismissible(
      key: ValueKey('attention-swipe-${item.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: Tokens.scoreHigh,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceL),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: Tokens.spaceS),
            Text('Paid', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      // The row leaves via the data stream, never by the Dismissible.
      confirmDismiss: (_) async {
        await payWithChain(context, ref, p);
        return false;
      },
      child: tile,
    );
  }
}
