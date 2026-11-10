import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log/app_log.dart';
import '../../core/money.dart';
import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../security/security_providers.dart';
import 'data/capture_service.dart';
import 'ocr/document_analysis.dart';
import 'ocr/field_extractor.dart';
import 'platform/capture_platform.dart';

// Device services — inert by default (web preview, tests); `main()`
// overrides them with the real plugins on phones.
final documentScannerProvider = Provider<DocumentScanner>(
  (ref) => const NoCapture(),
);
final fileImporterProvider = Provider<FileImporter>((ref) => const NoCapture());
final storageInfoProvider = Provider<StorageInfo>((ref) => const NoCapture());
final shareInboxProvider = Provider<ShareInbox>((ref) => const NoCapture());

/// On-device OCR (PBI-004). ML Kit on phones; no text elsewhere.
final textReaderProvider = Provider<TextReader>((ref) => const NoTextReader());

/// Where Vault files are stored (`<app documents>/vault`). Set in `main()`.
final vaultRootProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('vaultRootProvider must be overridden'),
);

final captureServiceProvider = Provider<CaptureService>(
  (ref) => CaptureService(
    ref.watch(repositoriesProvider),
    ref.watch(vaultRootProvider),
    now: ref.watch(nowProvider),
    crypto: ref.watch(vaultCryptoProvider),
  ),
);

/// Warn before scanning below this much free space (PBI-003 AC6).
const lowStorageMb = 100;

/// What the user has chosen for one draft on the confirm step. Kept in the
/// session so going back to the batch list never loses an edit.
class DraftEdits {
  const DraftEdits({
    required this.title,
    this.type,
    this.titleEdited = false,
    this.fields = const {},
    this.extracted = const {},
    this.folderId,
    this.folderChosen = false,
    this.personId,
    this.format = OutputFormat.pdf,
  });

  final String title;

  /// Null until a type is known: below the confidence threshold the user
  /// picks one (PBI-004 AC1).
  final String? type;
  final bool titleEdited;

  /// Field values as shown (amount formatted, e.g. "4,850").
  final Map<String, String> fields;

  /// What OCR put in each field, as shown — edits differ from it.
  final Map<String, String> extracted;
  final String? folderId;
  final bool folderChosen;
  final String? personId;
  final OutputFormat format;

  /// Field values as stored (amount in minor units).
  Map<String, String> get storedFields => {
    for (final e in fields.entries)
      e.key: e.key == Fields.amount
          ? (Money.parseMinor(e.value)?.toString() ?? '')
          : e.value.trim(),
  };

  Set<String> get corrected => {
    for (final e in fields.entries)
      if (e.value.trim() != (extracted[e.key] ?? '')) e.key,
  };

  /// The title the fields suggest, or [fallback] without a type.
  String autoTitleFor(DateTime now, String fallback) => type == null
      ? fallback
      : autoTitle(type!, {
          for (final e in storedFields.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        }, now);

  DraftEdits copyWith({
    String? title,
    bool? titleEdited,
    Map<String, String>? fields,
    String? folderId,
    bool clearFolder = false,
    bool? folderChosen,
    String? personId,
    bool clearPerson = false,
    OutputFormat? format,
  }) => DraftEdits(
    title: title ?? this.title,
    type: type,
    titleEdited: titleEdited ?? this.titleEdited,
    fields: fields ?? this.fields,
    extracted: extracted,
    folderId: clearFolder ? null : folderId ?? this.folderId,
    folderChosen: folderChosen ?? this.folderChosen,
    personId: clearPerson ? null : personId ?? this.personId,
    format: format ?? this.format,
  );

  /// Switches to [newType] with its [found] fields; the folder follows the
  /// type unless the user picked one, the title unless they typed one.
  DraftEdits withType(
    String newType,
    Map<String, Extracted> found, {
    required List<Folder> folders,
    required DateTime now,
    required String fallbackTitle,
  }) {
    final shown = <String, String>{
      for (final key in Fields.forType[newType] ?? const <String>[])
        key: switch (found[key]?.value) {
          final v? when key == Fields.amount && v.isNotEmpty =>
            Money.formatPlain(int.parse(v)),
          final v => v ?? '',
        },
    };
    final kind = folderKindFor(newType);
    final next = DraftEdits(
      title: title,
      type: newType,
      titleEdited: titleEdited,
      fields: shown,
      extracted: shown,
      folderId: folderChosen
          ? folderId
          : folders.where((f) => f.kind == kind).firstOrNull?.id,
      folderChosen: folderChosen,
      personId: personId,
      format: format,
    );
    return titleEdited
        ? next
        : next.copyWith(title: next.autoTitleFor(now, fallbackTitle));
  }
}

/// One document waiting to be filed.
class DraftEntry {
  const DraftEntry({
    required this.id,
    required this.draft,
    this.analysis,
    this.edits,
    this.renewsDocumentId,
    this.duplicateOf,
  });

  /// Stable within the session (widget keys, undo).
  final int id;
  final CaptureDraft draft;

  /// Null while the document is still being read.
  final DocumentAnalysis? analysis;

  /// Null until [analysis] is in.
  final DraftEdits? edits;

  /// Set when the session started from "Mark renewed" (PBI-008); only the
  /// first document of the session renews.
  final String? renewsDocumentId;

  /// Set when "Save all" held this one back as a possible duplicate.
  final Document? duplicateOf;

  bool get reading => analysis == null;

  /// Can be filed without opening it: read, typed, not a possible
  /// duplicate.
  bool get ready => edits?.type != null && duplicateOf == null;

  DraftEntry copyWith({
    DocumentAnalysis? analysis,
    DraftEdits? edits,
    Document? duplicateOf,
    bool clearDuplicate = false,
  }) => DraftEntry(
    id: id,
    draft: draft,
    analysis: analysis ?? this.analysis,
    edits: edits ?? this.edits,
    renewsDocumentId: renewsDocumentId,
    duplicateOf: clearDuplicate ? null : duplicateOf ?? this.duplicateOf,
  );
}

/// Documents captured in this session, waiting to be filed (batch mode),
/// plus where the session was started from (pre-selects folder/person).
class CaptureSession {
  const CaptureSession({
    this.entries = const [],
    this.folderId,
    this.personId,
    this.renewsDocumentId,
  });

  /// In capture order; the newest is last.
  final List<DraftEntry> entries;
  final String? folderId;
  final String? personId;

  /// Set when the session started from "Mark renewed" (PBI-008).
  final String? renewsDocumentId;

  List<CaptureDraft> get drafts => [for (final e in entries) e.draft];

  DraftEntry? byId(int id) => entries.where((e) => e.id == id).firstOrNull;

  CaptureSession withEntries(List<DraftEntry> entries) => entries.isEmpty
      ? const CaptureSession()
      : CaptureSession(
          entries: entries,
          folderId: folderId,
          personId: personId,
          renewsDocumentId: renewsDocumentId,
        );
}

class CaptureSessionNotifier extends Notifier<CaptureSession> {
  var _nextId = 0;

  @override
  CaptureSession build() => const CaptureSession();

  /// Queues [draft] and starts reading it straight away, so it is usually
  /// ready by the time the user looks at it.
  int add(
    CaptureDraft draft, {
    String? folderId,
    String? personId,
    String? renewsDocumentId,
  }) {
    final first = state.entries.isEmpty;
    final entry = DraftEntry(
      id: _nextId++,
      draft: draft,
      renewsDocumentId: first ? renewsDocumentId : null,
    );
    state = CaptureSession(
      entries: [...state.entries, entry],
      folderId: first ? folderId : state.folderId,
      personId: first ? personId : state.personId,
      renewsDocumentId: first ? renewsDocumentId : state.renewsDocumentId,
    );
    _analyze(entry);
    return entry.id;
  }

  Future<void> _analyze(DraftEntry entry) async {
    DocumentAnalysis analysis;
    var folders = const <Folder>[];
    try {
      final repos = ref.read(repositoriesProvider);
      analysis = await analyzeDraft(
        entry.draft,
        ref.read(textReaderProvider),
        repos,
      );
      folders = await repos.folders.getAll();
    } on Object catch (e, st) {
      // A failing recogniser must not leave "Reading…" up forever: the
      // document is filed like an unreadable one (PBI-004 AC5).
      AppLog.e('ocr', 'reading failed: ${e.runtimeType}', st);
      analysis = DocumentAnalysis.empty;
    }
    if (!ref.mounted || state.byId(entry.id) == null) return;

    final now = ref.read(nowProvider)();
    final fallback = defaultScanTitle(now);
    final c = analysis.classification;
    var edits = DraftEdits(
      title: fallback,
      folderId: state.folderId,
      folderChosen: state.folderId != null,
      personId: state.personId,
    );
    // AC1: below the threshold nothing is preselected — the user picks.
    // AC5: unreadable documents are simply "other" (Unclassified).
    if (analysis.unreadable || c.isConfident) {
      edits = edits.withType(
        c.type,
        analysis.fields,
        folders: folders,
        now: now,
        fallbackTitle: fallback,
      );
    }
    _update(entry.id, (e) => e.copyWith(analysis: analysis, edits: edits));
  }

  void updateEdits(int id, DraftEdits edits) =>
      _update(id, (e) => e.copyWith(edits: edits));

  void markDuplicate(int id, Document? of) => _update(
    id,
    (e) => e.copyWith(duplicateOf: of, clearDuplicate: of == null),
  );

  void _update(int id, DraftEntry Function(DraftEntry) change) {
    state = state.withEntries([
      for (final e in state.entries) e.id == id ? change(e) : e,
    ]);
  }

  /// Takes [id] out (saved or discarded). Returns it and where it was, for
  /// undo.
  (DraftEntry, int)? remove(int id) {
    final index = state.entries.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final entry = state.entries[index];
    state = state.withEntries([...state.entries]..removeAt(index));
    return (entry, index);
  }

  /// Puts a discarded entry back where it was.
  void restore(DraftEntry entry, int index) {
    if (state.byId(entry.id) != null) return;
    final list = [...state.entries];
    list.insert(index.clamp(0, list.length), entry);
    state = CaptureSession(
      entries: list,
      folderId: state.entries.isEmpty ? null : state.folderId,
      personId: state.entries.isEmpty ? null : state.personId,
      renewsDocumentId: state.renewsDocumentId,
    );
  }

  void clear() => state = const CaptureSession();
}

final captureSessionProvider =
    NotifierProvider<CaptureSessionNotifier, CaptureSession>(
      CaptureSessionNotifier.new,
    );
