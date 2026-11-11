import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import '../capture/capture_entry.dart';
import 'data/vault_service.dart';
import 'domain/vault_rules.dart';
import 'bundle_screen.dart' show bundleLocation;
import 'ui/document_tile.dart';
import 'ui/vault_sheets.dart';
import 'vault_providers.dart';
import '../../core/theme/tokens.dart';

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
/// Long-press starts multi-select → "Share as one PDF" (PBI-028a).
class VaultListScreen extends ConsumerStatefulWidget {
  const VaultListScreen({super.key, required this.scope});

  final VaultScope scope;

  @override
  ConsumerState<VaultListScreen> createState() => _VaultListScreenState();
}

class _VaultListScreenState extends ConsumerState<VaultListScreen> {
  /// Selected document ids, in the order they were picked.
  final _selected = <String>[];

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final docs = ref.watch(documentsProvider).value ?? const <Document>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final l = context.l10n;

    final (
      String title,
      Iterable<Document> scoped,
      List<Widget> actions,
    ) = switch (scope) {
      FolderScope(:final folderId) => () {
        final f = folders.where((f) => f.id == folderId).firstOrNull;
        return (
          f == null ? l.vtFolder : '${f.icon} ${folderLabel(f)}',
          docs.where((d) => d.folderId == folderId),
          [if (f != null && !isSystemFolder(f)) _FolderMenu(folder: f)],
        );
      }(),
      PersonScope(:final personId) => () {
        final p = persons.where((p) => p.id == personId).firstOrNull;
        return (
          p == null ? l.vtPerson : '${p.avatar ?? '👤'} ${p.name}',
          docs.where((d) => d.personId == personId),
          [if (p != null) _PersonMenu(person: p)],
        );
      }(),
      UnfiledScope() => (
        l.vtUnfiledTitle,
        docs.where((d) => d.folderId == null),
        const <Widget>[],
      ),
    };
    // Archived documents leave folder lists (still searchable).
    final list = sortDocuments(scoped.where((d) => d.archivedAt == null));

    final selecting = _selected.isNotEmpty;
    return Scaffold(
      appBar: selecting
          ? AppBar(
              leading: IconButton(
                key: const ValueKey('select-clear'),
                tooltip: l.shClearSelection,
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              ),
              title: Text(l.shSelected('${_selected.length}')),
              actions: [
                IconButton(
                  key: const ValueKey('select-share-pdf'),
                  tooltip: l.shShareAsPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () {
                    final ids = [..._selected];
                    setState(_selected.clear);
                    context.push(bundleLocation(ids: ids));
                  },
                ),
              ],
            )
          : AppBar(title: Text(title), actions: actions),
      body: list.isEmpty
          ? EmptyState(
              emoji: '📂',
              title: l.vtEmptyTitle,
              message: l.vtEmptyMessage,
              actionLabel: l.vtScanAction,
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
              padding: EdgeInsets.only(bottom: Tokens.listEnd),
              children: [
                for (final d in list)
                  DocumentTile(
                    document: d,
                    selected: selecting ? _selected.contains(d.id) : null,
                    onTap: selecting ? () => _toggle(d.id) : null,
                    onLongPress: () => _toggle(d.id),
                  ),
              ],
            ),
    );
  }
}

class _FolderMenu extends ConsumerWidget {
  const _FolderMenu({required this.folder});
  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return PopupMenuButton<String>(
      key: const ValueKey('folder-menu'),
      tooltip: l.vtFolderOptions,
      onSelected: (v) async {
        if (v == 'rename') {
          await showFolderSheet(context, folder: folder);
          return;
        }
        final ok = await _confirm(
          context,
          title: l.vtDeleteFolderTitle(folder.name),
          body: l.vtDeleteFolderBody,
        );
        if (!ok) return;
        await ref.read(vaultServiceProvider).deleteFolder(folder.id);
        if (context.mounted) context.go('/vault');
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'rename', child: Text(l.vtRename)),
        PopupMenuItem(
          key: const ValueKey('folder-delete'),
          value: 'delete',
          child: Text(l.vtDeleteFolder),
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
    final l = context.l10n;
    return PopupMenuButton<String>(
      key: const ValueKey('person-menu'),
      tooltip: l.vtPersonOptions,
      onSelected: (v) async {
        if (v == 'edit') {
          await showPersonSheet(context, person: person);
          return;
        }
        final ok = await _confirm(
          context,
          title: l.vtRemovePersonTitle(person.name),
          body: l.vtRemovePersonBody,
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
        PopupMenuItem(value: 'edit', child: Text(l.vtEdit)),
        if (!isSelf)
          PopupMenuItem(
            key: const ValueKey('person-delete'),
            value: 'delete',
            child: Text(l.vtRemovePerson),
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
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.vtDelete),
        ),
      ],
    ),
  );
  return ok == true;
}
