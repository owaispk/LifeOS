import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../core/l10n.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../../shared/format.dart';
import '../domain/duplicate_check.dart';
import '../domain/image_checks.dart';
import '../domain/pdf_builder.dart';
import '../../security/crypto/vault_crypto.dart';
import '../../../core/log/app_log.dart';

enum OutputFormat { pdf, jpeg }

/// One document waiting to be filed: scanned pages, or an imported /
/// shared file.
class CaptureDraft {
  CaptureDraft.scan(this.pagePaths) : importedPdf = null, source = 'scan';

  CaptureDraft.importImages(this.pagePaths, {this.source = 'import'})
    : importedPdf = null;

  CaptureDraft.importPdf(String path, {this.source = 'import'})
    : pagePaths = const [],
      importedPdf = path;

  /// Image pages (scan or imported images), in order.
  final List<String> pagePaths;

  /// An imported/shared PDF, stored as-is.
  final String? importedPdf;

  /// scan | import | share_in
  final String source;

  bool get isPdfImport => importedPdf != null;
}

/// Details chosen on the confirm step.
class FilingDetails {
  const FilingDetails({
    required this.title,
    this.folderId,
    this.personId,
    this.format = OutputFormat.pdf,
    this.docType = 'other',
    this.confidence,
    this.ocrText,
    this.fields = const {},
    this.corrected = const {},
    this.renewsDocumentId,
    String? issuer,
    String? refNumber,
    String? periodMonth,
  }) : issuerOverride = issuer,
       refOverride = refNumber,
       periodOverride = periodMonth;

  final String title;
  final String? folderId;
  final String? personId;
  final OutputFormat format;

  /// Classification and extraction from the confirm step (PBI-004).
  final String docType;
  final double? confidence;
  final String? ocrText;

  /// Final field values by `Fields` key (after the user's edits).
  final Map<String, String> fields;

  /// Field keys the user changed from what OCR extracted.
  final Set<String> corrected;

  /// The document this one renews (PBI-008): it gets archived and linked.
  final String? renewsDocumentId;

  /// Explicit values (tests, PBI-004 callers) that win over [fields].
  final String? issuerOverride;
  final String? refOverride;
  final String? periodOverride;

  String? _f(String key) {
    final v = fields[key]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? get issuer => issuerOverride ?? _f('issuer') ?? _f('institution');
  String? get refNumber => refOverride ?? _f('ref_number') ?? _f('number');
  String? get periodMonth => periodOverride ?? _f('period_month');
  int? get amountMinor => int.tryParse(_f('amount') ?? '');
  String? get dueDate => _f('due_date');
  String? get issueDate => _f('issue_date') ?? _f('start_date');
  String? get expiryDate => _f('expiry_date') ?? _f('end_date');
}

/// What an image page looks like to the checks (computed off the UI
/// isolate).
class PageCheck {
  const PageCheck({required this.sharpness, required this.hash});
  final double sharpness;
  final String hash;

  bool get isBlurry => sharpness < blurThreshold;
}

/// Saves captures into the Vault (PBI-003). Files live under
/// `<vaultRoot>/<documentId>/<fileId>.<ext>`.
class CaptureService {
  CaptureService(
    this._repos,
    this._vaultRoot, {
    DateTime Function()? now,
    this.crypto,
  }) : _now = now ?? DateTime.now;

  final Repositories _repos;
  final Directory _vaultRoot;
  final DateTime Function() _now;

  /// Encrypts files at rest (PBI-024). The app always provides it; only
  /// low-level tests construct the service without it.
  final VaultCrypto? crypto;

  String defaultTitle() => defaultScanTitle(_now());

  /// Sharpness + perceptual hash of one image page.
  static Future<PageCheck> checkPage(String path) async {
    final bytes = await File(path).readAsBytes();
    return Isolate.run(() {
      final image = img.decodeImage(bytes);
      if (image == null) return const PageCheck(sharpness: 0, hash: '');
      return PageCheck(
        sharpness: sharpness(image),
        hash: differenceHash(image),
      );
    });
  }

  /// An existing live document this capture duplicates, if any: same
  /// issuer + reference + period, or the same paper scanned again — a near
  /// first-page image hash *and*, when both were read, matching OCR text
  /// (PBI-003 AC7). The hash alone mistakes two bills from one company for
  /// each other.
  Future<Document?> findDuplicate(
    CaptureDraft draft, {
    FilingDetails? details,
  }) async {
    final docs = {for (final d in await _repos.documents.getAll()) d.id: d};

    if (details?.issuer != null &&
        details?.refNumber != null &&
        details?.periodMonth != null) {
      for (final d in docs.values) {
        if (d.issuer == details!.issuer &&
            d.refNumber == details.refNumber &&
            d.periodMonth == details.periodMonth) {
          return d;
        }
      }
    }

    if (draft.pagePaths.isEmpty) return null;
    final hash = (await checkPage(draft.pagePaths.first)).hash;
    if (hash.isEmpty) return null;
    final text = details?.ocrText ?? '';
    for (final f in await _repos.documentFiles.getAll()) {
      if (f.pageNo != 1 || f.phash == null) continue;
      final doc = docs[f.documentId];
      if (doc != null &&
          isDuplicateCapture(
            newHash: hash,
            oldHash: f.phash!,
            newText: text,
            oldText: doc.ocrText ?? '',
          )) {
        return doc;
      }
    }
    return null;
  }

  /// Deletes a saved document's files from disk. Used when an outer
  /// transaction (e.g. the payment chain, PBI-016) rolls back after save.
  Future<void> discardFiles(String documentId) async {
    final dir = Directory(p.join(_vaultRoot.path, documentId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Writes the files and creates the document + file rows.
  Future<Document> save(CaptureDraft draft, FilingDetails details) async {
    final title = details.title.trim().isEmpty
        ? defaultTitle()
        : details.title.trim();

    // Prepare file contents first (pure work, nothing written yet).
    final files = <_PreparedFile>[];
    if (draft.isPdfImport) {
      files.add(
        _PreparedFile(
          await File(draft.importedPdf!).readAsBytes(),
          'application/pdf',
          'pdf',
          null,
        ),
      );
    } else {
      final pages = <Uint8List>[];
      final hashes = <String?>[];
      for (final path in draft.pagePaths) {
        final raw = await File(path).readAsBytes();
        final prepared = await _prepareOffThread(raw);
        pages.add(prepared.$1);
        hashes.add(prepared.$2);
      }
      if (details.format == OutputFormat.pdf) {
        files.add(
          _PreparedFile(
            await buildPdf(pages),
            'application/pdf',
            'pdf',
            hashes.first,
          ),
        );
      } else {
        for (var i = 0; i < pages.length; i++) {
          files.add(_PreparedFile(pages[i], 'image/jpeg', 'jpg', hashes[i]));
        }
      }
    }

    Directory? dir;
    try {
      return await _repos.db.transaction(() async {
        final doc = await _repos.documents.insert(
          DocumentsCompanion.insert(
            title: title,
            folderId: Value(details.folderId),
            personId: Value(details.personId),
            source: Value(draft.source),
            issuer: Value(details.issuer),
            refNumber: Value(details.refNumber),
            periodMonth: Value(details.periodMonth),
            docType: Value(details.docType),
            classificationConfidence: Value(details.confidence),
            ocrText: Value(details.ocrText),
            amountMinor: Value(details.amountMinor),
            dueDate: Value(details.dueDate),
            issueDate: Value(details.issueDate),
            expiryDate: Value(details.expiryDate),
          ),
        );
        // Renewal (PBI-008): archive the old document, keep it searchable,
        // and link it to its replacement.
        if (details.renewsDocumentId != null) {
          await _repos.documents.update(
            details.renewsDocumentId!,
            DocumentsCompanion(
              archivedAt: Value(_now().millisecondsSinceEpoch),
              renewedById: Value(doc.id),
            ),
          );
        }
        // One row per extracted field; corrections feed per-issuer
        // learning (PBI-004 AC6).
        for (final e in details.fields.entries) {
          if (e.value.trim().isEmpty) continue;
          await _repos.extractedFields.insert(
            ExtractedFieldsCompanion.insert(
              documentId: doc.id,
              field: e.key,
              value: e.value.trim(),
              corrected: Value(details.corrected.contains(e.key)),
            ),
          );
        }
        dir = await Directory(p.join(_vaultRoot.path, doc.id))
            .create(recursive: true);
        for (var i = 0; i < files.length; i++) {
          final f = files[i];
          // AC1: what reaches the disk is AES-256-GCM ciphertext; the hash
          // is of the ciphertext (integrity of what is stored).
          final blob = await crypto?.encrypt(f.bytes);
          final stored = blob?.bytes ?? f.bytes;
          final row = await _repos.documentFiles.insert(
            DocumentFilesCompanion.insert(
              documentId: doc.id,
              pageNo: Value(i + 1),
              byteSize: f.bytes.length,
              mime: Value(f.mime),
              sha256: sha256.convert(stored).toString(),
              phash: Value(f.phash),
              encIv: Value(blob?.iv),
              encKeyWrapped: Value(blob?.wrappedKey),
            ),
          );
          final path = p.join(dir!.path, '${row.id}.${f.ext}');
          await File(path).writeAsBytes(stored, flush: true);
          await _repos.documentFiles.update(
            row.id,
            DocumentFilesCompanion(localPath: Value(path)),
          );
        }
        AppLog.i(
          'capture',
          'saved ${details.docType} · ${files.length} file(s) · '
              '${draft.source}${crypto == null ? '' : ' · encrypted'}',
        );
        return doc;
      });
    } on Object catch (e, st) {
      AppLog.e('capture', 'save failed: ${e.runtimeType}', st);
      // Never leave orphan files behind a rolled-back document.
      if (dir != null && await dir!.exists()) {
        await dir!.delete(recursive: true);
      }
      rethrow;
    }
  }
}

/// "Scan · 8 Nov 2026" — the name a capture gets before anything is known.
String defaultScanTitle(DateTime now) =>
    l10nNow.cpScanTitle(dayMonth(now), '${now.year}');

class _PreparedFile {
  const _PreparedFile(this.bytes, this.mime, this.ext, this.phash);
  final Uint8List bytes;
  final String mime;
  final String ext;
  final String? phash;
}

/// Runs [_toJpeg] on a background isolate. Kept top-level so the closure
/// captures only the bytes — never the service or its database connection.
Future<(Uint8List, String?)> _prepareOffThread(Uint8List raw) =>
    Isolate.run(() => _toJpeg(raw));

/// Normalises a page to an upright JPEG and hashes it (runs in a background
/// isolate).
///
/// Camera/scanner JPEGs often store pixels sideways plus an EXIF
/// orientation tag. `decodeImage` already bakes that rotation into the
/// pixels, so a tagged JPEG is re-encoded from the decoded image; keeping
/// the raw bytes would leave the rotation to each viewer / the PDF writer,
/// which renders the page rotated.
(Uint8List, String?) _toJpeg(Uint8List raw) {
  final image = img.decodeImage(raw);
  if (image == null) return (raw, null);
  final isJpeg = raw.length > 2 && raw[0] == 0xFF && raw[1] == 0xD8;
  final keepRaw = isJpeg && !_hasRotation(raw);
  final bytes = keepRaw ? raw : img.encodeJpg(image, quality: 90);
  return (bytes, differenceHash(image));
}

/// True if a JPEG carries an EXIF orientation other than "upright".
bool _hasRotation(Uint8List jpeg) {
  final ifd = img.decodeJpgExif(jpeg)?.imageIfd;
  return ifd != null && ifd.hasOrientation && ifd.orientation != 1;
}
