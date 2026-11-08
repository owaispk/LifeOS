import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import '../capture/ocr/doc_classifier.dart' show docTypes;
import '../capture/ocr/field_extractor.dart' show typeName;
import '../money/domain/money_rules.dart' show isoDate;
import 'domain/vault_rules.dart';
import 'ui/document_pages.dart';
import 'ui/document_sheet.dart';
import 'vault_providers.dart';

final documentFilesProvider = StreamProvider.family<List<DocumentFile>, String>(
  (ref, docId) => ref
      .watch(repositoriesProvider)
      .documentFiles
      .watchWhere((f) => f.documentId.equals(docId))
      .map((l) => l..sort((a, b) => a.pageNo.compareTo(b.pageNo))),
);

final linkedTasksProvider = StreamProvider.family<List<Task>, String>(
  (ref, docId) => ref
      .watch(repositoriesProvider)
      .tasks
      .watchWhere((t) => t.sourceDocumentId.equals(docId)),
);

/// 3.3 Document Viewer (PBI-007).
class DocumentViewerScreen extends ConsumerWidget {
  const DocumentViewerScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider).value;
    final doc = docs?.where((d) => d.id == documentId).firstOrNull;
    final files =
        ref.watch(documentFilesProvider(documentId)).value ??
        const <DocumentFile>[];

    if (docs != null && doc == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          emoji: '🗑️',
          title: 'This document is gone',
          message: 'It was deleted. Look in Vault → Trash to restore it.',
        ),
      );
    }
    if (doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final service = ref.read(vaultServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (doc.archivedAt != null)
            const Padding(
              padding: EdgeInsets.only(right: Tokens.spaceS),
              child: Chip(label: Text('Archived')),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: DocumentPages(files: files)),
          _InfoPanel(document: doc),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Tokens.spaceXs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Action(
                key: const ValueKey('viewer-share'),
                icon: Icons.ios_share,
                label: 'Share',
                onTap: files.isEmpty
                    ? null
                    : () => ref.read(shareFilesProvider)(files),
              ),
              _Action(
                key: const ValueKey('viewer-edit'),
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () => showDocumentSheet(context, doc.id),
              ),
              _Action(
                key: const ValueKey('viewer-archive'),
                icon: doc.archivedAt == null
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
                label: doc.archivedAt == null ? 'Archive' : 'Unarchive',
                onTap: () async {
                  if (doc.archivedAt == null) {
                    await service.archive(doc.id);
                  } else {
                    await service.unarchive(doc.id);
                  }
                },
              ),
              _Action(
                key: const ValueKey('viewer-delete'),
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await service.deleteDocument(doc.id);
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: const Text('Moved to Trash'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => ref
                              .read(repositoriesProvider)
                              .documents
                              .restore(doc.id),
                        ),
                      ),
                    );
                  if (context.mounted && context.canPop()) context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 32,
      // Minimum touch height, but grows with large text (no overflow).
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 72,
          minHeight: Tokens.minTouchTarget,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Swipe-up details: type, main fields (editable), tags, linked tasks.
class _InfoPanel extends ConsumerWidget {
  const _InfoPanel({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final doc = document;
    final service = ref.read(vaultServiceProvider);
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final tasks =
        ref.watch(linkedTasksProvider(doc.id)).value ?? const <Task>[];
    final person = persons.where((p) => p.id == doc.personId).firstOrNull;
    final folder = folders.where((f) => f.id == doc.folderId).firstOrNull;
    final tags = parseTags(doc.tags);

    Future<void> save(DocumentsCompanion c) => service.updateDetails(doc.id, c);

    return DraggableScrollableSheet(
      key: const ValueKey('viewer-info'),
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.9,
      snap: true,
      builder: (context, controller) => Material(
        elevation: 6,
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Tokens.radius),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            Tokens.spaceM,
            Tokens.spaceS,
            Tokens.spaceM,
            Tokens.spaceXl,
          ),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Tokens.spaceS),
            Text(
              'Details',
              key: const ValueKey('viewer-details'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Tokens.spaceM),
            DropdownButtonFormField<String>(
              key: const ValueKey('info-type'),
              initialValue: doc.docType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in docTypes)
                  DropdownMenuItem(
                    value: t,
                    child: Text('${docTypeIcon(t)} ${typeName(t)}'),
                  ),
              ],
              onChanged: (t) {
                if (t != null) save(DocumentsCompanion(docType: Value(t)));
              },
            ),
            _TextDetail(
              key: ValueKey('info-issuer-${doc.version}'),
              field: 'issuer',
              label: 'Issuer',
              value: doc.issuer,
              onSave: (v) => save(DocumentsCompanion(issuer: Value(v))),
            ),
            _TextDetail(
              key: ValueKey('info-ref-${doc.version}'),
              field: 'ref',
              label: 'Reference / number',
              value: doc.refNumber,
              onSave: (v) => save(DocumentsCompanion(refNumber: Value(v))),
            ),
            _TextDetail(
              key: ValueKey('info-amount-${doc.version}'),
              field: 'amount',
              label: 'Amount',
              value: doc.amountMinor == null
                  ? null
                  : Money.format(doc.amountMinor!).replaceFirst('Rs ', ''),
              prefix: 'Rs ',
              onSave: (v) => save(
                DocumentsCompanion(
                  amountMinor: Value(v == null ? null : Money.parseMinor(v)),
                ),
              ),
            ),
            _DateDetail(
              field: 'due',
              label: 'Due date',
              value: doc.dueDate,
              onSave: (v) => save(DocumentsCompanion(dueDate: Value(v))),
            ),
            _DateDetail(
              field: 'expiry',
              label: 'Expiry date',
              value: doc.expiryDate,
              onSave: (v) => save(DocumentsCompanion(expiryDate: Value(v))),
            ),
            const SizedBox(height: Tokens.spaceM),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                folder == null ? 'Unfiled' : '${folder.icon} ${folder.name}',
              ),
              subtitle: Text(
                person == null
                    ? 'Nobody'
                    : '${person.avatar ?? '👤'} ${person.name}',
              ),
              trailing: TextButton(
                key: const ValueKey('info-move'),
                onPressed: () => showDocumentSheet(context, doc.id),
                child: const Text('Move'),
              ),
            ),
            if (tags.isNotEmpty)
              Wrap(
                spacing: Tokens.spaceS,
                children: [for (final t in tags) Chip(label: Text(t))],
              ),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: Tokens.spaceM),
              Text('Linked tasks', style: theme.textTheme.labelLarge),
              for (final t in tasks)
                ListTile(
                  key: ValueKey('linked-task-${t.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    t.status == 'done'
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(t.title),
                  onTap: () => context.go('/tasks/task/${t.id}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A text field that saves when the user confirms (Enter / leaving it).
class _TextDetail extends StatefulWidget {
  const _TextDetail({
    super.key,
    required this.field,
    required this.label,
    required this.value,
    required this.onSave,
    this.prefix,
  });

  final String field;
  final String label;
  final String? value;
  final String? prefix;
  final Future<void> Function(String? value) onSave;

  @override
  State<_TextDetail> createState() => _TextDetailState();
}

class _TextDetailState extends State<_TextDetail> {
  late final _ctrl = TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit() {
    final v = _ctrl.text.trim();
    if (v != (widget.value ?? '')) widget.onSave(v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.spaceS),
      child: TextField(
        key: ValueKey('info-field-${widget.field}'),
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: widget.prefix,
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) {
          _commit();
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}

class _DateDetail extends ConsumerWidget {
  const _DateDetail({
    required this.field,
    required this.label,
    required this.value,
    required this.onSave,
  });

  final String field;
  final String label;
  final String? value;
  final Future<void> Function(String? value) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: ValueKey('info-field-$field'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(label),
      subtitle: Text(value ?? 'Not set'),
      onTap: () async {
        final now = ref.read(nowProvider)();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value ?? '') ?? now,
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (picked != null) await onSave(isoDate(picked));
      },
      trailing: value == null
          ? null
          : IconButton(
              tooltip: 'Clear $label',
              icon: const Icon(Icons.close),
              onPressed: () => onSave(null),
            ),
    );
  }
}
