import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../vault/vault_providers.dart';
import 'capture_entry.dart';
import 'capture_providers.dart';
import 'data/capture_service.dart';

/// 3.4 Scan Flow — confirm step ("Review & file"), one draft at a time.
/// PBI-004 adds type detection and extracted fields to this screen.
class CaptureReviewScreen extends ConsumerWidget {
  const CaptureReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(captureSessionProvider);
    final drafts = session.drafts;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          drafts.length <= 1
              ? 'Save to Vault'
              : 'Save to Vault · 1 of ${drafts.length}',
          key: const ValueKey('review-title'),
        ),
        actions: [
          IconButton(
            key: const ValueKey('review-scan-another'),
            tooltip: 'Scan another',
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: () => startScan(
              context,
              folderId: session.folderId,
              personId: session.personId,
            ),
          ),
          IconButton(
            key: const ValueKey('review-import'),
            tooltip: 'Import a file',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => importFiles(
              context,
              folderId: session.folderId,
              personId: session.personId,
            ),
          ),
        ],
      ),
      body: drafts.isEmpty
          ? const Center(child: Text('Nothing left to file'))
          : _DraftForm(
              // A fresh form for every draft.
              key: ObjectKey(drafts.first),
              draft: drafts.first,
              folderId: session.folderId,
              personId: session.personId,
            ),
    );
  }
}

class _DraftForm extends ConsumerStatefulWidget {
  const _DraftForm({
    super.key,
    required this.draft,
    required this.folderId,
    required this.personId,
  });

  final CaptureDraft draft;
  final String? folderId;
  final String? personId;

  @override
  ConsumerState<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends ConsumerState<_DraftForm> {
  late final _title = TextEditingController(
    text: ref.read(captureServiceProvider).defaultTitle(),
  );
  late String? _folderId = widget.folderId;
  late String? _personId = widget.personId;
  OutputFormat _format = OutputFormat.pdf;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final service = ref.read(captureServiceProvider);
    final details = FilingDetails(
      title: _title.text,
      folderId: _folderId,
      personId: _personId,
      format: _format,
    );
    try {
      final duplicate = await service.findDuplicate(
        widget.draft,
        details: details,
      );
      if (duplicate != null) {
        if (!mounted) return;
        final keep = await _askDuplicate(context, duplicate);
        if (!keep) {
          _advance(saved: false);
          return;
        }
      }
      await service.save(widget.draft, details);
      _advance(saved: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _advance({required bool saved}) {
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(captureSessionProvider.notifier);
    final last = ref.read(captureSessionProvider).drafts.length <= 1;
    session.next();
    // The newest outcome replaces any message still showing.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(saved ? 'Saved to Vault' : 'Duplicate discarded')),
    );
    if (last && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final draft = widget.draft;

    return ListView(
      padding: const EdgeInsets.all(Tokens.spaceM),
      children: [
        _PagesStrip(draft: draft),
        const SizedBox(height: Tokens.spaceM),
        TextField(
          key: const ValueKey('review-name'),
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Tokens.spaceM),
        DropdownButtonFormField<String?>(
          key: const ValueKey('review-folder'),
          initialValue: _folderId,
          decoration: const InputDecoration(
            labelText: 'Folder',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('📥 Unfiled')),
            for (final f in folders)
              DropdownMenuItem(value: f.id, child: Text('${f.icon} ${f.name}')),
          ],
          onChanged: (v) => setState(() => _folderId = v),
        ),
        const SizedBox(height: Tokens.spaceM),
        DropdownButtonFormField<String?>(
          key: const ValueKey('review-person'),
          initialValue: _personId,
          decoration: const InputDecoration(
            labelText: 'Belongs to',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Nobody')),
            for (final p in persons)
              DropdownMenuItem(
                value: p.id,
                child: Text('${p.avatar ?? '👤'} ${p.name}'),
              ),
          ],
          onChanged: (v) => setState(() => _personId = v),
        ),
        if (!draft.isPdfImport) ...[
          const SizedBox(height: Tokens.spaceM),
          Text('Save as', style: theme.textTheme.labelLarge),
          const SizedBox(height: Tokens.spaceS),
          SegmentedButton<OutputFormat>(
            key: const ValueKey('review-format'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: OutputFormat.pdf, label: Text('PDF')),
              ButtonSegment(value: OutputFormat.jpeg, label: Text('JPEG')),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
        ],
        const SizedBox(height: Tokens.spaceL),
        FilledButton.icon(
          key: const ValueKey('review-save'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(Tokens.minTouchTarget + 4),
          ),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt),
          label: const Text('Save to Vault'),
        ),
        const SizedBox(height: Tokens.spaceS),
        TextButton(
          key: const ValueKey('review-discard'),
          onPressed: _saving ? null : () => _advance(saved: false),
          child: const Text('Discard this one'),
        ),
      ],
    );
  }
}

Future<bool> _askDuplicate(BuildContext context, Document existing) async {
  final keep = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('dialog-duplicate'),
      title: const Text('Possible duplicate'),
      content: Text(
        'Looks like a duplicate of \'${existing.title}\'. Keep both?',
      ),
      actions: [
        TextButton(
          key: const ValueKey('duplicate-discard'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Discard new'),
        ),
        FilledButton(
          key: const ValueKey('duplicate-keep'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Keep both'),
        ),
      ],
    ),
  );
  return keep == true;
}

class _PagesStrip extends StatelessWidget {
  const _PagesStrip({required this.draft});
  final CaptureDraft draft;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = draft.isPdfImport ? 1 : draft.pagePaths.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (draft.isPdfImport)
                _PageBox(
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 48,
                    color: scheme.primary,
                  ),
                )
              else
                for (final path in draft.pagePaths)
                  _PageBox(
                    child: kIsWeb
                        ? const Icon(Icons.image_outlined)
                        : Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                          ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.spaceXs),
        Text(
          count == 1 ? '1 page' : '$count pages',
          key: const ValueKey('review-pages'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _PageBox extends StatelessWidget {
  const _PageBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Tokens.spaceS),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
