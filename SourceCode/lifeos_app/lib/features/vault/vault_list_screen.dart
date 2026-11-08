import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import '../capture/capture_entry.dart';
import 'data/vault_service.dart';
import 'domain/vault_rules.dart';
import 'ui/document_tile.dart';
import 'ui/vault_sheets.dart';
import 'vault_providers.dart';

/// What a [VaultListScreen] shows.
sealed class VaultScope {
  const VaultScope();
}

class FolderScope extends VaultScope {
  const FolderScope(this.folderId);
  final String folderId;
}

class PersonScope extends VaultScope {
  const PersonScope(this.personId);
  final String personId;
}

class UnfiledScope extends VaultScope {
  const UnfiledScope();
}

/// 3.2 Folder / Person view: that scope's documents, favourites first.
class VaultListScreen extends ConsumerWidget {
  const VaultListScreen({super.key, required this.scope});

  final VaultScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider).value ?? const <Document>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];

    final (
      String title,
      Iterable<Document> scoped,
      List<Widget> actions,
    ) = switch (scope) {
      FolderScope(:final folderId) => () {
        final f = folders.where((f) => f.id == folderId).firstOrNull;
        return (
          f == null ? 'Folder' : '${f.icon} ${f.name}',
          docs.where((d) => d.folderId == folderId),
          [if (f != null && !isSystemFolder(f)) _FolderMenu(folder: f)],
        );
      }(),
      PersonScope(:final personId) => () {
        final p = persons.where((p) => p.id == personId).firstOrNull;
        return (
          p == null ? 'Person' : '${p.avatar ?? '👤'} ${p.name}',
          docs.where((d) => d.personId == personId),
          [if (p != null) _PersonMenu(person: p)],
        );
      }(),
      UnfiledScope() => (
        '📥 Unfiled',
        docs.where((d) => d.folderId == null),
        const <Widget>[],
      ),
    };
    // Archived documents leave folder lists (still searchable).
    final list = sortDocuments(scoped.where((d) => d.archivedAt == null));

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: list.isEmpty
          ? EmptyState(
              emoji: '📂',
              title: 'Nothing here yet',
              message: 'Scan or import a document to file it here.',
              actionLabel: '📸 Scan',
              onAction: () => startScan(
                context,
                folderId: switch (scope) {
                  FolderScope(:final folderId) => folderId,
                  _ => null,
                },
                personId: switch (scope) {
                  PersonScope(:final personId) => personId,
                  _ => null,
                },
              ),
            )
          : ListView(
              key: const ValueKey('vault-list'),
              padding: const EdgeInsets.only(bottom: 120),
              children: [for (final d in list) DocumentTile(document: d)],
            ),
    );
  }
}

class _FolderMenu extends ConsumerWidget {
  const _FolderMenu({required this.folder});
  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const ValueKey('folder-menu'),
      tooltip: 'Folder options',
      onSelected: (v) async {
        if (v == 'rename') {
          await showFolderSheet(context, folder: folder);
          return;
        }
        final ok = await _confirm(
          context,
          title: 'Delete "${folder.name}"?',
          body: 'Its documents move to Unfiled — nothing is lost.',
        );
        if (!ok) return;
        await ref.read(vaultServiceProvider).deleteFolder(folder.id);
        if (context.mounted) context.go('/vault');
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(
          key: ValueKey('folder-delete'),
          value: 'delete',
          child: Text('Delete folder'),
        ),
      ],
    );
  }
}

class _PersonMenu extends ConsumerWidget {
  const _PersonMenu({required this.person});
  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelf = person.relation == 'self';
    return PopupMenuButton<String>(
      key: const ValueKey('person-menu'),
      tooltip: 'Person options',
      onSelected: (v) async {
        if (v == 'edit') {
          await showPersonSheet(context, person: person);
          return;
        }
        final ok = await _confirm(
          context,
          title: 'Remove ${person.name}?',
          body: 'Their documents stay in the Vault, unassigned.',
        );
        if (!ok) return;
        try {
          await ref.read(vaultServiceProvider).deletePerson(person.id);
          if (context.mounted) context.go('/vault');
        } on ProtectedItemException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (!isSelf)
          const PopupMenuItem(
            key: ValueKey('person-delete'),
            value: 'delete',
            child: Text('Remove person'),
          ),
      ],
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}
