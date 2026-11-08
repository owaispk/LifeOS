import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../money/domain/money_rules.dart' show isoDate;
import '../vault/domain/vault_rules.dart' show docTypeIcon;
import '../vault/vault_providers.dart';
import 'capture_entry.dart';
import 'capture_providers.dart';
import 'data/capture_service.dart';
import 'ocr/doc_classifier.dart';
import 'ocr/document_analysis.dart';
import 'ocr/field_extractor.dart';

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
  final _title = TextEditingController();
  late String? _folderId = widget.folderId;
  late String? _personId = widget.personId;
  OutputFormat _format = OutputFormat.pdf;
  bool _saving = false;

  // PBI-004: OCR + classification.
  DocumentAnalysis? _analysis;
  String? _type; // null = user must pick (low confidence)
  final _fieldCtrls = <String, TextEditingController>{};
  final _extracted = <String, String>{};
  bool _titleEdited = false;
  bool _folderChosen = false;

  @override
  void initState() {
    super.initState();
    _folderChosen = widget.folderId != null;
    _title.text = ref.read(captureServiceProvider).defaultTitle();
    _title.addListener(() {
      if (_title.text != _autoTitle()) _titleEdited = true;
    });
    _analyze();
  }

  Future<void> _analyze() async {
    final analysis = await analyzeDraft(
      widget.draft,
      ref.read(textReaderProvider),
      ref.read(repositoriesProvider),
    );
    if (!mounted) return;
    setState(() {
      _analysis = analysis;
      final c = analysis.classification;
      // AC1: below the threshold nothing is preselected — the user picks.
      // AC5: unreadable documents are simply "other" (Unclassified).
      _type = analysis.unreadable || c.isConfident ? c.type : null;
      if (_type != null) _applyType(_type!, analysis.fields);
    });
  }

  void _applyType(String type, Map<String, Extracted> fields) {
    _type = type;
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    _fieldCtrls.clear();
    _extracted.clear();
    for (final key in Fields.forType[type] ?? const <String>[]) {
      final raw = fields[key]?.value ?? '';
      final shown = key == Fields.amount && raw.isNotEmpty
          ? Money.format(int.parse(raw)).replaceFirst('Rs ', '')
          : raw;
      _extracted[key] = shown;
      _fieldCtrls[key] = TextEditingController(text: shown)
        ..addListener(_refreshTitle);
    }
    if (!_folderChosen) {
      final kind = folderKindFor(type);
      final folders = ref.read(foldersProvider).value ?? const <Folder>[];
      _folderId = folders.where((f) => f.kind == kind).firstOrNull?.id;
    }
    _refreshTitle();
  }

  Map<String, String> _values() => {
    for (final e in _fieldCtrls.entries)
      e.key: e.key == Fields.amount
          ? (Money.parseMinor(e.value.text)?.toString() ?? '')
          : e.value.text.trim(),
  };

  String _autoTitle() {
    final type = _type;
    if (type == null || _analysis == null) {
      return ref.read(captureServiceProvider).defaultTitle();
    }
    return autoTitle(type, {
      for (final e in _values().entries)
        if (e.value.isNotEmpty) e.key: e.value,
    }, ref.read(nowProvider)());
  }

  void _refreshTitle() {
    if (_titleEdited) return;
    final next = _autoTitle();
    if (_title.text != next) {
      _title.value = TextEditingValue(text: next);
      _titleEdited = false;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _type == null) return;
    setState(() => _saving = true);
    final service = ref.read(captureServiceProvider);
    final values = _values();
    final analysis = _analysis ?? DocumentAnalysis.empty;
    final details = FilingDetails(
      title: _title.text,
      folderId: _folderId,
      personId: _personId,
      format: _format,
      docType: _type!,
      confidence: analysis.unreadable
          ? null
          : analysis.classification.scores.isEmpty
          ? 0
          : analysis.classification.confidence,
      ocrText: analysis.unreadable ? null : analysis.ocrText,
      fields: values,
      corrected: {
        for (final e in _fieldCtrls.entries)
          if (e.value.text.trim() != (_extracted[e.key] ?? '')) e.key,
      },
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

  Future<void> _pickDate(String key) async {
    final ctrl = _fieldCtrls[key]!;
    final current = DateTime.tryParse(ctrl.text) ?? ref.read(nowProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ctrl.text = isoDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final draft = widget.draft;
    final analysis = _analysis;

    return ListView(
      padding: const EdgeInsets.all(Tokens.spaceM),
      children: [
        _PagesStrip(draft: draft),
        const SizedBox(height: Tokens.spaceM),
        if (analysis == null)
          const Padding(
            key: ValueKey('review-reading'),
            padding: EdgeInsets.symmetric(vertical: Tokens.spaceS),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: Tokens.spaceS),
                Text('Reading document…'),
              ],
            ),
          )
        else
          _TypeRow(
            analysis: analysis,
            type: _type,
            onPick: (t) => setState(() => _applyType(t, analysis.fieldsFor(t))),
          ),
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
        for (final e in _fieldCtrls.entries) ...[
          const SizedBox(height: Tokens.spaceS),
          TextField(
            key: ValueKey('review-field-${e.key}'),
            controller: e.value,
            readOnly: Fields.isDate(e.key),
            onTap: Fields.isDate(e.key) ? () => _pickDate(e.key) : null,
            keyboardType: e.key == Fields.amount
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: Fields.labels[e.key],
              prefixText: e.key == Fields.amount ? 'Rs ' : null,
              suffixIcon: Fields.isDate(e.key) ? const Icon(Icons.event) : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: Tokens.spaceM),
        DropdownButtonFormField<String?>(
          key: ValueKey('review-folder-$_folderId'),
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
          onChanged: (v) => setState(() {
            _folderId = v;
            _folderChosen = true;
          }),
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
          // AC2: nothing is saved before this tap; a type is required.
          onPressed: _saving || _type == null ? null : _save,
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

/// Detected type as a chip with confidence, or a picker when unsure.
class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.analysis,
    required this.type,
    required this.onPick,
  });

  final DocumentAnalysis analysis;
  final String? type;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = analysis.classification;
    final confident = !analysis.unreadable && c.isConfident;
    final message = analysis.unreadable
        ? "Couldn't read any text — saved as Unclassified. Pick a type if "
              'you like.'
        : confident
        ? null
        : 'Not sure what this is — please pick a type.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.spaceS),
            child: Text(
              message,
              key: const ValueKey('review-type-hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Row(
          children: [
            if (type != null)
              Chip(
                key: const ValueKey('review-type-chip'),
                avatar: Text(docTypeIcon(type!)),
                label: Text(
                  confident && type == c.type
                      ? '${typeName(type!)} · ${(c.confidence * 100).round()}%'
                      : typeName(type!),
                ),
              ),
            const SizedBox(width: Tokens.spaceS),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const ValueKey('review-type-picker'),
                initialValue: type,
                hint: const Text('Pick a type'),
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final t in docTypes)
                    DropdownMenuItem(
                      value: t,
                      child: Text('${docTypeIcon(t)} ${typeName(t)}'),
                    ),
                ],
                onChanged: (t) {
                  if (t != null) onPick(t);
                },
              ),
            ),
          ],
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
