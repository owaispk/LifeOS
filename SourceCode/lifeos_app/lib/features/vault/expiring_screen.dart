import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/now_provider.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import 'domain/vault_rules.dart';
import 'vault_providers.dart';

/// 3.6 Expiring Soon (PBI-008): soonest first; deleted and archived
/// documents never appear; urgency is colour + icon + text.
class ExpiringScreen extends ConsumerWidget {
  const ExpiringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider).value ?? const <Document>[];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final now = ref.watch(nowProvider)();
    final items = expiringSoon(docs, now);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.vtExpiringSoon)),
      body: items.isEmpty
          ? EmptyState(
              emoji: '✅',
              title: context.l10n.vtNothingExpiring,
              message: context.l10n.vtNothingExpiringMessage,
            )
          : ListView(
              key: const ValueKey('expiring-list'),
              children: [
                for (final e in items)
                  () {
                    final (color, icon) = switch (e.urgency) {
                      ExpiryUrgency.critical => (
                        scheme.error,
                        Icons.error_outline,
                      ),
                      ExpiryUrgency.soon => (
                        const Color(0xFFB26A00),
                        Icons.schedule,
                      ),
                      ExpiryUrgency.later => (scheme.outline, Icons.event),
                    };
                    final person = persons
                        .where((p) => p.id == e.document.personId)
                        .firstOrNull;
                    return ListTile(
                      key: ValueKey('expiring-row-${e.document.id}'),
                      leading: Icon(icon, color: color),
                      title: Text(e.document.title),
                      subtitle: Text(
                        [e.label, if (person != null) person.name].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/doc/${e.document.id}'),
                    );
                  }(),
              ],
            ),
    );
  }
}
