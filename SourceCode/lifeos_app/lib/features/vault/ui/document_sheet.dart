import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../domain/vault_rules.dart';
import '../vault_providers.dart';

/// Small document sheet (PBI-005): title, favourite, tags, folder, person,
/// delete. The full viewer is PBI-007.
Future<void> showDocumentSheet(BuildContext context, String documentId) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    isScrollControlled: true,
    builder: (context) => DocumentSheet(documentId: documentId),
  );
}

class DocumentSheet extends ConsumerStatefulWidget {
  const DocumentSheet({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocumentSheet> createState() => _DocumentSheetState();
}

class _DocumentSheetState extends ConsumerState<DocumentSheet> {
  final _title = TextEditingController();
  final _tag = TextEditingController();
  bool _initialised = false;

  @override
  void dispose() {
    _title.dispose();
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final docs = ref.watch(documentsProvider).value ?? const <Document>[];
    final doc = docs.where((d) => d.id == widget.documentId).firstOrNull;
    if (doc == null) {
      return SizedBox(
        height: 160,
        child: Center(child: Text(context.l10n.vtDocGoneTitle)),
      );
    }
    if (!_initialised) {
      _title.text = doc.title;
      _initialised = true;
    }
    final service = ref.read(vaultServiceProvider);
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final tags = parseTags(doc.tags);
    final l = context.l10n;

    void saveTitle() {
      final t = _title.text.trim();
      if (t.isEmpty) {
        _title.text = doc.title;
      } else if (t != doc.title) {
        service.renameDocument(doc.id, t);
      }
    }

    void addTag() {
      final t = _tag.text.trim();
      if (t.isEmpty) return;
      service.setTags(doc.id, [...tags, t]);
      _tag.clear();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.spaceM,
        right: Tokens.spaceM,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.spaceM,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  docTypeIcon(doc.docType),
                  style: const TextStyle(fontSize: 28),
                ),
                SizedBox(width: Tokens.spaceS),
                Expanded(
                  child: TextField(
                    key: const ValueKey('doc-title'),
                    controller: _title,
                    style: theme.textTheme.titleLarge,
                    decoration: const InputDecoration(border: InputBorder.none),
                    onSubmitted: (_) => saveTitle(),
                    onTapOutside: (_) {
                      saveTitle();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                IconButton(
                  key: const ValueKey('doc-favorite'),
                  tooltip: doc.favorite
                      ? l.vtRemoveFavourite
                      : l.vtAddFavourite,
                  icon: Icon(doc.favorite ? Icons.star : Icons.star_border),
                  onPressed: () => service.setFavorite(doc.id, !doc.favorite),
                ),
              ],
            ),
            _Label(l.vtFolder),
            DropdownButtonFormField<String?>(
              key: const ValueKey('doc-folder'),
              initialValue: doc.folderId,
              items: [
                DropdownMenuItem(value: null, child: Text(l.vtUnfiledTitle)),
                for (final f in folders)
                  DropdownMenuItem(
                    value: f.id,
                    child: Text('${f.icon} ${folderLabel(f)}'),
                  ),
              ],
              onChanged: (v) =>
                  service.move(doc.id, folderId: v, personId: doc.personId),
            ),
            _Label(l.vtBelongsTo),
            DropdownButtonFormField<String?>(
              key: const ValueKey('doc-person'),
              initialValue: doc.personId,
              items: [
                DropdownMenuItem(value: null, child: Text(l.vtNobody)),
                for (final p in persons)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text([p.avatar ?? '👤', p.name].join(' ')),
                  ),
              ],
              onChanged: (v) =>
                  service.move(doc.id, folderId: doc.folderId, personId: v),
            ),
            _Label(l.vtTags),
            Wrap(
              spacing: Tokens.spaceS,
              children: [
                for (final t in tags)
                  InputChip(
                    key: ValueKey('tag-$t'),
                    label: Text(t),
                    onDeleted: () =>
                        service.setTags(doc.id, tags.where((x) => x != t)),
                    deleteButtonTooltipMessage: l.vtRemoveTag(t),
                  ),
              ],
            ),
            TextField(
              key: const ValueKey('doc-add-tag'),
              controller: _tag,
              decoration: InputDecoration(
                hintText: l.vtAddTagHint,
                prefixIcon: const Icon(Icons.sell_outlined),
                suffixIcon: IconButton(
                  tooltip: l.vtAddTag,
                  icon: const Icon(Icons.add),
                  onPressed: addTag,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => addTag(),
            ),
            SizedBox(height: Tokens.spaceM),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('doc-delete'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(l.vtDelete),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l.vtDeleteDocTitle),
                      content: Text(l.vtDeleteDocBody(doc.title)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l.cancel),
                        ),
                        FilledButton(
                          key: const ValueKey('confirm-delete-doc'),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l.vtDelete),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await service.deleteDocument(doc.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: Tokens.spaceM, bottom: Tokens.spaceXs),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}
