import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import 'data/trash_service.dart';
import 'domain/vault_rules.dart';
import 'vault_providers.dart';

final trashServiceProvider = Provider<TrashService>(
  (ref) => TrashService(
    ref.watch(repositoriesProvider),
    now: ref.watch(nowProvider),
  ),
);

final trashedDocumentsProvider = FutureProvider.autoDispose<List<Document>>((
  ref,
) {
  ref.watch(documentsProvider); // refresh after deletes / restores
  return ref.watch(trashServiceProvider).trashed();
});

/// Vault → Trash (PBI-007): restore or delete forever; 30-day purge.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashed = ref.watch(trashedDocumentsProvider);
    final service = ref.read(trashServiceProvider);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.trash)),
      body: trashed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            EmptyState(emoji: '⚠️', title: l.vtTrashUnavailable, message: ''),
        data: (docs) => docs.isEmpty
            ? EmptyState(
                emoji: '🗑️',
                title: l.vtTrashEmpty,
                message: l.vtTrashEmptyMessage('$trashDays'),
              )
            : ListView(
                key: const ValueKey('trash-list'),
                children: [
                  for (final d in docs)
                    ListTile(
                      key: ValueKey('trash-${d.id}'),
                      leading: Text(
                        docTypeIcon(d.docType),
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(d.title),
                      subtitle: Text(
                        l.vtTrashDaysLeft('${service.daysLeft(d)}'),
                        key: ValueKey('trash-days-${d.id}'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            key: ValueKey('trash-restore-${d.id}'),
                            onPressed: () => service.restore(d.id),
                            child: Text(l.vtRestore),
                          ),
                          IconButton(
                            key: ValueKey('trash-forever-${d.id}'),
                            tooltip: l.deleteForever,
                            icon: const Icon(Icons.delete_forever_outlined),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l.vtDeleteForeverTitle),
                                  content: Text(l.vtDeleteForeverBody(d.title)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(l.cancel),
                                    ),
                                    FilledButton(
                                      key: const ValueKey('confirm-forever'),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(l.deleteForever),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await service.deleteForever(d.id);
                                ref.invalidate(trashedDocumentsProvider);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
