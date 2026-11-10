import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../atc/atc_providers.dart';
import '../atc/data/atc_learning.dart' show LearningOutcome;
import '../atc/ui/proposal_dialog.dart';
import '../money/domain/money_rules.dart' show isoDate;
import '../vault/domain/vault_rules.dart' show docTypeIcon;
import '../vault/vault_providers.dart';
import 'capture_entry.dart';
import 'capture_providers.dart';
import '../premium/premium_providers.dart';
import '../ai/ai_providers.dart' show isAiRead;
import '../ai/ui/ai_card.dart';
import '../premium/ui/upgrade_prompt.dart';
import 'data/capture_service.dart';
import 'ocr/doc_classifier.dart';
import 'ocr/document_analysis.dart';
import 'ocr/field_extractor.dart';

/// 3.4 Scan Flow — confirm step ("Review & file").
///
/// One document: its form straight away. Several: a list with one card
/// per document (newest first), each read in the background; ready ones
/// are filed together with "Save all", the rest opened and checked.
class CaptureReviewScreen extends ConsumerStatefulWidget {
  const CaptureReviewScreen({super.key});

  @override
  ConsumerState<CaptureReviewScreen> createState() =>
      _CaptureReviewScreenState();
}

class _CaptureReviewScreenState extends ConsumerState<CaptureReviewScreen> {
  /// The document opened from the batch list, if any.
  int? _openId;
  bool _savingAll = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionProvider);
    final entries = session.entries;
    final l = context.l10n;

    final opened = entries.length == 1
        ? entries.single
        : _openId == null
        ? null
        : session.byId(_openId!);
    final inBatch = entries.length > 1;

    return Scaffold(
      appBar: AppBar(
        leading: inBatch && opened != null
            ? IconButton(
                key: const ValueKey('review-back-to-list'),
                tooltip: l.cpAllDocuments,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _openId = null),
              )
            : null,
        title: Text(
          opened != null || entries.isEmpty
              ? l.cpSaveToVault
              : l.cpBatchTitle(entries.length),
          key: const ValueKey('review-title'),
        ),
        actions: [
          IconButton(
            key: const ValueKey('review-scan-another'),
            tooltip: l.cpScanAnother,
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: _scanAnother,
          ),
          IconButton(
            key: const ValueKey('review-import'),
            tooltip: l.cpImportFile,
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _import,
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Text(l.cpNothingLeft))
          : opened != null
          ? _DraftForm(
              // One form per document; edits live in the session.
              key: ValueKey('draft-${opened.id}'),
              entryId: opened.id,
              onDone: _afterFiling,
              onScanAnother: _scanAnother,
              onImport: _import,
            )
          : _BatchList(
              entries: entries,
              saving: _savingAll,
              onOpen: (id) => setState(() => _openId = id),
              onSaveAll: _saveAll,
              onScanAnother: _scanAnother,
              onImport: _import,
            ),
    );
  }

  void _scanAnother() {
    final s = ref.read(captureSessionProvider);
    // The new scan shows on top of the list, not hidden behind this one.
    setState(() => _openId = null);
    startScan(
      context,
      folderId: s.folderId,
      personId: s.personId,
      renewsDocumentId: s.renewsDocumentId,
    );
  }

  void _import() {
    final s = ref.read(captureSessionProvider);
    setState(() => _openId = null);
    importFiles(context, folderId: s.folderId, personId: s.personId);
  }

  /// Back to the list after a document was filed or discarded; closes the
  /// screen when nothing is left.
  void _afterFiling() {
    if (!mounted) return;
    setState(() => _openId = null);
    if (ref.read(captureSessionProvider).entries.isEmpty) context.pop();
  }

  Future<void> _saveAll() async {
    if (_savingAll) return;
    setState(() => _savingAll = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    var saved = 0, held = 0;
    var limitHit = false;
    final notes = <String>{};
    try {
      final ready = ref
          .read(captureSessionProvider)
          .entries
          .where((e) => e.ready)
          .toList();
      for (final e in ready) {
        if (!mounted) break;
        final result = await fileEntry(context, ref, e, askDuplicate: false);
        switch (result) {
          case FileSaved(:final note):
            saved++;
            if (note != null) notes.add(note);
          case FileHeldBack():
            held++;
          case FileDiscarded():
            break;
          case FileLimitReached():
            // The free plan is full: the rest would hit the same wall,
            // and the prompt has already been shown once.
            limitHit = true;
        }
        if (limitHit) break;
      }
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            l.cpSavedCount(saved),
            if (held > 0) l.cpHeldBack(held),
            ...notes,
          ].join(' · '),
        ),
      ),
    );
    _afterFiling();
  }
}

// ───────────────────────────── Filing ─────────────────────────────

sealed class FileResult {
  const FileResult();
}

class FileSaved extends FileResult {
  const FileSaved(this.note);

  /// "Unusually high bill" / "Bill task updated", if any.
  final String? note;
}

/// The user chose "Discard new" on the duplicate question.
class FileDiscarded extends FileResult {
  const FileDiscarded();
}

/// A possible duplicate kept back for the user to check ("Save all").
class FileHeldBack extends FileResult {
  const FileHeldBack();
}

/// The free plan is full (PBI-029 AC1). The capture stays in the session
/// so "Not now" never throws away a scan the user has already taken.
class FileLimitReached extends FileResult {
  const FileLimitReached();
}

FilingDetails _detailsFor(DraftEntry entry) {
  final e = entry.edits!;
  final a = entry.analysis ?? DocumentAnalysis.empty;
  return FilingDetails(
    title: e.title,
    folderId: e.folderId,
    personId: e.personId,
    format: e.format,
    renewsDocumentId: entry.renewsDocumentId,
    docType: e.type!,
    confidence: a.unreadable
        ? null
        : a.classification.scores.isEmpty
        ? 0
        : a.classification.confidence,
    ocrText: a.unreadable ? null : a.ocrText,
    fields: e.storedFields,
    corrected: e.corrected,
  );
}

/// Saves one document to the Vault and takes it out of the session. A
/// possible duplicate is asked about ([askDuplicate]) or held back.
Future<FileResult> fileEntry(
  BuildContext context,
  WidgetRef ref,
  DraftEntry entry, {
  required bool askDuplicate,
}) async {
  // Everything from `ref` is read up front: the form that called this may
  // be gone by the end (its document leaves the session).
  final l = context.l10n;
  final service = ref.read(captureServiceProvider);
  final session = ref.read(captureSessionProvider.notifier);
  final atc = ref.read(atcLearningProvider);
  final now = ref.read(nowProvider)();
  final details = _detailsFor(entry);

  // Free plan full? Ask before saving, and keep the capture (AC1).
  if (!ref.read(canSaveDocumentProvider)) {
    if (context.mounted) await showUpgradePrompt(context, reason: UpgradeReason.documents);
    return const FileLimitReached();
  }

  final duplicate = await service.findDuplicate(entry.draft, details: details);
  if (duplicate != null) {
    if (!askDuplicate || !context.mounted) {
      session.markDuplicate(entry.id, duplicate);
      return const FileHeldBack();
    }
    final keep = await _askDuplicate(context, duplicate, now);
    if (!keep) {
      session.remove(entry.id);
      return const FileDiscarded();
    }
  }

  final doc = await service.save(entry.draft, details);
  final LearningOutcome outcome;
  try {
    // Bills and fee vouchers teach the Auto Task Creator (PBI-014/015).
    outcome = await atc.onDocumentSaved(doc);
    final change = outcome.feeChange;
    if (change != null && context.mounted) {
      final update = await showFeeChangeDialog(context, change);
      if (update) await atc.applyFeeChange(change);
    }
  } finally {
    // Saved: it must never be offered for saving again.
    session.remove(entry.id);
  }
  return FileSaved(
    outcome.spike
        ? l.cpUnusualBill
        : outcome.upgradedTaskId != null
        ? l.cpBillTaskUpdated
        : null,
  );
}

Future<bool> _askDuplicate(
  BuildContext context,
  Document existing,
  DateTime now,
) async {
  final saved = formatDay(
    DateTime.fromMillisecondsSinceEpoch(existing.updatedAt),
    now: now,
  );
  final keep = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('dialog-duplicate'),
      title: Text(context.l10n.cpDuplicateTitle),
      content: Text(context.l10n.cpDuplicateBody(existing.title, saved)),
      actions: [
        TextButton(
          key: const ValueKey('duplicate-discard'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cpDiscardNew),
        ),
        FilledButton(
          key: const ValueKey('duplicate-keep'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.cpKeepBoth),
        ),
      ],
    ),
  );
  return keep == true;
}

// ───────────────────────────── Batch list ─────────────────────────────

class _BatchList extends ConsumerWidget {
  const _BatchList({
    required this.entries,
    required this.saving,
    required this.onOpen,
    required this.onSaveAll,
    required this.onScanAnother,
    required this.onImport,
  });

  final List<DraftEntry> entries;
  final bool saving;
  final ValueChanged<int> onOpen;
  final VoidCallback onSaveAll;
  final VoidCallback onScanAnother;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ready = entries.where((e) => e.ready).length;
    final newestId = entries.last.id;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(Tokens.spaceM),
            children: [
              Text(
                l.cpBatchHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: Tokens.spaceS),
              for (final e in entries.reversed)
                _DraftCard(
                  entry: e,
                  isNew: e.id == newestId,
                  onTap: saving ? null : () => onOpen(e.id),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Tokens.spaceM,
              Tokens.spaceS,
              Tokens.spaceM,
              Tokens.spaceM,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  key: const ValueKey('batch-save-all'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      Tokens.minTouchTarget + 4,
                    ),
                  ),
                  onPressed: saving || ready == 0 ? null : onSaveAll,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(l.cpSaveReady(ready)),
                ),
                SizedBox(height: Tokens.spaceS),
                _AddMoreRow(
                  scanKey: 'batch-scan-another',
                  importKey: 'batch-import',
                  onScanAnother: saving ? null : onScanAnother,
                  onImport: saving ? null : onImport,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftCard extends ConsumerWidget {
  const _DraftCard({
    required this.entry,
    required this.isNew,
    required this.onTap,
  });

  final DraftEntry entry;
  final bool isNew;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = entry.edits;
    final draft = entry.draft;
    final now = ref.watch(nowProvider)();

    final amount = e?.fields[Fields.amount] ?? '';
    final pages = draft.isPdfImport ? 1 : draft.pagePaths.length;
    final subtitle = entry.duplicateOf != null
        ? l.cpMaybeDuplicate(entry.duplicateOf!.title)
        : [
            if (e?.type != null) typeName(e!.type!) else if (!entry.reading)
              l.cpPickType,
            if (amount.isNotEmpty) '${Money.prefix}$amount',
            l.cpPages(pages),
          ].join(' · ');

    final (IconData icon, String status, Color color) = entry.reading
        ? (Icons.hourglass_top, l.cpStatusReading, scheme.onSurfaceVariant)
        : entry.ready
        ? (Icons.check_circle, l.cpStatusReady, scheme.primary)
        : (Icons.error_outline, l.cpStatusCheck, scheme.error);

    return Card(
      key: ValueKey('batch-card-${entry.id}'),
      margin: EdgeInsets.only(bottom: Tokens.spaceS),
      clipBehavior: Clip.antiAlias,
      shape: isNew
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.primary, width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(Tokens.spaceS),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: draft.isPdfImport || kIsWeb
                        ? Icon(
                            Icons.picture_as_pdf_outlined,
                            color: scheme.primary,
                          )
                        : Image.file(
                            File(draft.pagePaths.first),
                            fit: BoxFit.cover,
                            cacheWidth: 96,
                          ),
                  ),
                ),
              ),
              SizedBox(width: Tokens.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (e?.type != null) ...[
                          Text(docTypeIcon(e!.type!)),
                          SizedBox(width: Tokens.spaceXs),
                        ],
                        Expanded(
                          child: Text(
                            e?.title ?? defaultScanTitle(now),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (isNew)
                          Padding(
                            padding: EdgeInsets.only(left: Tokens.spaceXs),
                            child: Text(
                              l.cpStatusNew,
                              key: const ValueKey('batch-new'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: Tokens.spaceXxs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: entry.duplicateOf != null
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Tokens.spaceS),
              Column(
                key: ValueKey('batch-status-${entry.id}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.reading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(icon, color: color, size: 20),
                  SizedBox(height: Tokens.spaceXxs),
                  Text(
                    status,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMoreRow extends StatelessWidget {
  const _AddMoreRow({
    required this.scanKey,
    required this.importKey,
    required this.onScanAnother,
    required this.onImport,
  });

  final String scanKey;
  final String importKey;
  final VoidCallback? onScanAnother;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: ValueKey(scanKey),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
            ),
            onPressed: onScanAnother,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(l.cpScanAnother, overflow: TextOverflow.ellipsis),
          ),
        ),
        SizedBox(width: Tokens.spaceS),
        Expanded(
          child: OutlinedButton.icon(
            key: ValueKey(importKey),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
            ),
            onPressed: onImport,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(l.cpImportFile, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── One document ─────────────────────────────

class _DraftForm extends ConsumerStatefulWidget {
  const _DraftForm({
    super.key,
    required this.entryId,
    required this.onDone,
    required this.onScanAnother,
    required this.onImport,
  });

  final int entryId;
  final VoidCallback onDone;
  final VoidCallback onScanAnother;
  final VoidCallback onImport;

  @override
  ConsumerState<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends ConsumerState<_DraftForm> {
  TextEditingController? _title;
  final _fieldCtrls = <String, TextEditingController>{};
  bool _saving = false;

  DraftEntry? get _entry =>
      ref.read(captureSessionProvider).byId(widget.entryId);

  DateTime get _now => ref.read(nowProvider)();

  /// Controllers start from the session's edits once the document is read.
  void _ensureControllers(DraftEdits edits) {
    if (_title != null) return;
    _title = TextEditingController(text: edits.title)
      ..addListener(_onTitle);
    _resetFieldControllers(edits);
  }

  void _resetFieldControllers(DraftEdits edits) {
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    _fieldCtrls
      ..clear()
      ..addAll({
        for (final e in edits.fields.entries)
          e.key: TextEditingController(text: e.value)
            ..addListener(_onFields),
      });
  }

  void _put(DraftEdits edits) => ref
      .read(captureSessionProvider.notifier)
      .updateEdits(widget.entryId, edits);

  void _onTitle() {
    final e = _entry?.edits;
    final text = _title!.text;
    if (e == null || text == e.title) return;
    final auto = e.autoTitleFor(_now, defaultScanTitle(_now));
    _put(e.copyWith(title: text, titleEdited: text != auto));
  }

  void _onFields() {
    final e = _entry?.edits;
    if (e == null) return;
    var next = e.copyWith(
      fields: {for (final c in _fieldCtrls.entries) c.key: c.value.text},
    );
    if (!e.titleEdited) {
      next = next.copyWith(
        title: next.autoTitleFor(_now, defaultScanTitle(_now)),
      );
    }
    _put(next);
    if (_title!.text != next.title) {
      _title!.value = TextEditingValue(text: next.title);
    }
  }

  void _pickType(String type) {
    final entry = _entry;
    final e = entry?.edits;
    if (e == null) return;
    final next = e.withType(
      type,
      entry!.analysis!.fieldsFor(type),
      folders: ref.read(foldersProvider).value ?? const <Folder>[],
      now: _now,
      fallbackTitle: defaultScanTitle(_now),
    );
    setState(() => _resetFieldControllers(next));
    _put(next);
    if (_title!.text != next.title) {
      _title!.value = TextEditingValue(text: next.title);
    }
  }

  @override
  void dispose() {
    _title?.dispose();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final entry = _entry;
    if (_saving || entry == null || entry.edits?.type == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final result = await fileEntry(context, ref, entry, askDuplicate: true);
      messenger.hideCurrentSnackBar();
      // The limit prompt has already said its piece; a snackbar on top
      // of it would just repeat the bad news.
      if (result is! FileLimitReached) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (result) {
              FileSaved(:final note) => [l.cpSavedToVault, ?note].join(' · '),
              _ => l.cpDuplicateDiscarded,
            }),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    widget.onDone();
  }

  void _discard() {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l = context.l10n;
    final session = ref.read(captureSessionProvider.notifier);
    final removed = session.remove(widget.entryId);
    if (removed == null) return;
    final (entry, index) = removed;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.cpDiscarded),
        action: SnackBarAction(
          key: const ValueKey('discard-undo'),
          label: l.cpUndo,
          onPressed: () {
            session.restore(entry, index);
            // The screen closed if this was the last one: open it again.
            if (router.state.matchedLocation != captureRoute) {
              router.push(captureRoute);
            }
          },
        ),
      ),
    );
    widget.onDone();
  }

  Future<void> _pickDate(String key) async {
    final ctrl = _fieldCtrls[key]!;
    final current = DateTime.tryParse(ctrl.text) ?? _now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) ctrl.text = isoDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(
      captureSessionProvider.select((s) => s.byId(widget.entryId)),
    );
    if (entry == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final draft = entry.draft;
    final analysis = entry.analysis;
    final edits = entry.edits;
    if (edits != null) _ensureControllers(edits);
    final l = context.l10n;

    return ListView(
      padding: EdgeInsets.all(Tokens.spaceM),
      children: [
        _PagesStrip(draft: draft),
        SizedBox(height: Tokens.spaceM),
        if (entry.duplicateOf != null)
          Padding(
            padding: EdgeInsets.only(bottom: Tokens.spaceS),
            child: Text(
              l.cpMaybeDuplicate(entry.duplicateOf!.title),
              key: const ValueKey('review-duplicate-note'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (analysis == null || edits == null)
          Padding(
            key: const ValueKey('review-reading'),
            padding: EdgeInsets.symmetric(vertical: Tokens.spaceS),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: Tokens.spaceS),
                Text(l.cpReading),
              ],
            ),
          )
        else ...[
          // Cloud AI: consent, teaser, spinner or error (PBI-027a).
          AiCard(entryId: widget.entryId),
          _TypeRow(analysis: analysis, type: edits.type, onPick: _pickType),
          SizedBox(height: Tokens.spaceM),
          TextField(
            key: const ValueKey('review-name'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.name,
              border: const OutlineInputBorder(),
            ),
          ),
          for (final e in _fieldCtrls.entries) ...[
            SizedBox(height: Tokens.spaceS),
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
                prefixText: e.key == Fields.amount ? Money.prefix : null,
                suffixIcon: Fields.isDate(e.key)
                    ? const Icon(Icons.event)
                    : null,
                // Says where the value came from, so a field the phone
                // could not read is not mistaken for one it did (AC2).
                suffix: isAiRead(analysis.fields[e.key])
                    ? const AiBadge()
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          SizedBox(height: Tokens.spaceM),
          DropdownButtonFormField<String?>(
            key: ValueKey('review-folder-${edits.folderId}'),
            initialValue: edits.folderId,
            decoration: InputDecoration(
              labelText: l.cpFolder,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l.cpUnfiled)),
              for (final f in folders)
                DropdownMenuItem(
                  value: f.id,
                  child: Text('${f.icon} ${f.name}'),
                ),
            ],
            onChanged: (v) => _put(
              edits.copyWith(
                folderId: v,
                clearFolder: v == null,
                folderChosen: true,
              ),
            ),
          ),
          SizedBox(height: Tokens.spaceM),
          DropdownButtonFormField<String?>(
            key: const ValueKey('review-person'),
            initialValue: edits.personId,
            decoration: InputDecoration(
              labelText: l.cpBelongsTo,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l.cpNobody)),
              for (final p in persons)
                DropdownMenuItem(
                  value: p.id,
                  child: Text([p.avatar ?? '👤', p.name].join(' ')),
                ),
            ],
            onChanged: (v) =>
                _put(edits.copyWith(personId: v, clearPerson: v == null)),
          ),
          if (!draft.isPdfImport) ...[
            SizedBox(height: Tokens.spaceM),
            Text(l.cpSaveAs, style: theme.textTheme.labelLarge),
            SizedBox(height: Tokens.spaceS),
            SegmentedButton<OutputFormat>(
              key: const ValueKey('review-format'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: OutputFormat.pdf, label: Text(l.cpPdf)),
                ButtonSegment(value: OutputFormat.jpeg, label: Text(l.cpJpeg)),
              ],
              selected: {edits.format},
              onSelectionChanged: (s) => _put(edits.copyWith(format: s.first)),
            ),
          ],
        ],
        SizedBox(height: Tokens.spaceL),
        FilledButton.icon(
          key: const ValueKey('review-save'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(Tokens.minTouchTarget + 4),
          ),
          // AC2: nothing is saved before this tap; a type is required.
          onPressed: _saving || edits?.type == null ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt),
          label: Text(l.cpSaveToVault),
        ),
        SizedBox(height: Tokens.spaceS),
        TextButton(
          key: const ValueKey('review-discard'),
          onPressed: _saving ? null : _discard,
          child: Text(l.cpDiscardThis),
        ),
        SizedBox(height: Tokens.spaceS),
        _AddMoreRow(
          scanKey: 'review-scan-another-button',
          importKey: 'review-import-button',
          onScanAnother: _saving ? null : widget.onScanAnother,
          onImport: _saving ? null : widget.onImport,
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
    final l = context.l10n;
    final message = analysis.unreadable
        ? l.cpUnreadable
        : confident
        ? null
        : l.cpNotSure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message != null)
          Padding(
            padding: EdgeInsets.only(bottom: Tokens.spaceS),
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
                      ? l.cpTypeConfidence(
                          typeName(type!),
                          '${(c.confidence * 100).round()}',
                        )
                      : typeName(type!),
                ),
              ),
            SizedBox(width: Tokens.spaceS),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const ValueKey('review-type-picker'),
                initialValue: type,
                hint: Text(l.cpPickType),
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

// ───────────────────────────── Pages ─────────────────────────────

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
                for (var i = 0; i < draft.pagePaths.length; i++)
                  _PageBox(
                    key: ValueKey('review-page-$i'),
                    // Tap to check the page full screen, pinch to zoom.
                    onTap: kIsWeb
                        ? null
                        : () => _showPages(context, draft.pagePaths, i),
                    child: kIsWeb
                        ? const Icon(Icons.image_outlined)
                        : Image.file(
                            File(draft.pagePaths[i]),
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                          ),
                  ),
            ],
          ),
        ),
        SizedBox(height: Tokens.spaceXs),
        Text(
          context.l10n.cpPages(count),
          key: const ValueKey('review-pages'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

/// Width of a page thumbnail on the confirm step.
const _thumbWidth = 120.0;

class _PageBox extends StatelessWidget {
  const _PageBox({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: Tokens.spaceS),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: _thumbWidth, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

Future<void> _showPages(BuildContext context, List<String> paths, int start) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _PageViewer(paths: paths, start: start),
    ),
  );
}

class _PageViewer extends StatefulWidget {
  const _PageViewer({required this.paths, required this.start});
  final List<String> paths;
  final int start;

  @override
  State<_PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends State<_PageViewer> {
  late final _controller = PageController(initialPage: widget.start);
  late int _page = widget.start;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('page-viewer'),
      appBar: AppBar(
        title: Text(
          context.l10n.cpPageOf('${_page + 1}', '${widget.paths.length}'),
        ),
      ),
      body: PageView(
        controller: _controller,
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          for (final path in widget.paths)
            InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.file(File(path))),
            ),
        ],
      ),
    );
  }
}
