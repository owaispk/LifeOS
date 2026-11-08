import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../../shared/format.dart';
import '../domain/image_checks.dart';
import '../domain/pdf_builder.dart';

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
    this.issuer,
    this.refNumber,
    this.periodMonth,
  });

  final String title;
  final String? folderId;
  final String? personId;
  final OutputFormat format;

  /// Filled by OCR in PBI-004; part of the duplicate rule already.
  final String? issuer;
  final String? refNumber;
  final String? periodMonth;
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
  CaptureService(this._repos, this._vaultRoot, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Repositories _repos;
  final Directory _vaultRoot;
  final DateTime Function() _now;

  String defaultTitle() =>
      'Scan · ${formatDay(_now()).split(', ').last} '
      '${_now().year}';

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
  /// first-page image hash (near match), or same issuer + reference +
  /// period (PBI-003 AC7).
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
    for (final f in await _repos.documentFiles.getAll()) {
      if (f.pageNo != 1 || f.phash == null) continue;
      final doc = docs[f.documentId];
      if (doc != null && isNearDuplicate(hash, f.phash!)) return doc;
    }
    return null;
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
          ),
        );
        dir = await Directory(p.join(_vaultRoot.path, doc.id))
            .create(recursive: true);
        for (var i = 0; i < files.length; i++) {
          final f = files[i];
          final row = await _repos.documentFiles.insert(
            DocumentFilesCompanion.insert(
              documentId: doc.id,
              pageNo: Value(i + 1),
              byteSize: f.bytes.length,
              mime: Value(f.mime),
              sha256: sha256.convert(f.bytes).toString(),
              phash: Value(f.phash),
            ),
          );
          final path = p.join(dir!.path, '${row.id}.${f.ext}');
          await File(path).writeAsBytes(f.bytes, flush: true);
          await _repos.documentFiles.update(
            row.id,
            DocumentFilesCompanion(localPath: Value(path)),
          );
        }
        return doc;
      });
    } on Object {
      // Never leave orphan files behind a rolled-back document.
      if (dir != null && await dir!.exists()) {
        await dir!.delete(recursive: true);
      }
      rethrow;
    }
  }
}

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

/// Normalises a page to JPEG and hashes it (runs in a background isolate).
(Uint8List, String?) _toJpeg(Uint8List raw) {
  final image = img.decodeImage(raw);
  if (image == null) return (raw, null);
  final isJpeg = raw.length > 2 && raw[0] == 0xFF && raw[1] == 0xD8;
  final bytes = isJpeg ? raw : img.encodeJpg(image, quality: 90);
  return (bytes, differenceHash(image));
}
