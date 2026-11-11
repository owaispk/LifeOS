// Decrypted copies that must not outlive their use (PBI-024, PBI-028a AC2).
//
// Vault files are encrypted at rest, but some steps need a plain file on
// disk for a moment: the share sheet, PDF rendering, the file picker. These
// helpers keep those copies short-lived, and a start-up sweep removes
// anything a crash or a plugin left behind.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;

import 'log/app_log.dart';

/// Cache folders that only ever hold plaintext copies.
const plaintextCacheDirs = [
  'share', // our share copies (PBI-007)
  'share_plus', // share_plus copies every shared file here
  'bundle', // "Also save to the Vault" (PBI-028a)
  'pdf_open', // PDFs opened for rendering ([withTempFile])
  'file_picker', // imported files, already copied into the Vault
  'pdf_renderer_cache',
];

/// Removes leftover plaintext from [cache]: the folders above, and loose
/// `.pdf` files (pdfx's `openData` writes one per document and never
/// deletes it). Safe at start-up, when nothing is using them.
Future<int> sweepPlaintextCache(Directory cache) async {
  var removed = 0;
  if (!await cache.exists()) return 0;
  for (final name in plaintextCacheDirs) {
    final dir = Directory(p.join(cache.path, name));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      removed++;
    }
  }
  await for (final e in cache.list()) {
    if (e is File && p.extension(e.path).toLowerCase() == '.pdf') {
      await e.delete();
      removed++;
    }
  }
  if (removed > 0) AppLog.i('vault', 'swept $removed plaintext cache items');
  return removed;
}

/// Deletes share_plus's own copies once the share sheet has closed.
Future<void> clearShareSheetCopies(Directory cache) async {
  final dir = Directory(p.join(cache.path, 'share_plus'));
  if (await dir.exists()) await dir.delete(recursive: true);
}

/// Opens a decrypted PDF for rendering without leaving it on disk. pdfx's
/// `openData` writes its own copy into the cache and never removes it, so
/// the bytes go to a private temporary file instead, which is deleted as
/// soon as the renderer has it open (Android keeps reading through the
/// open file descriptor).
Future<pdfx.PdfDocument> openPdfPrivately(Directory cache, Uint8List bytes) =>
    withTempFile(cache, bytes, '.pdf', pdfx.PdfDocument.openFile);

/// Writes [bytes] to a private temporary file under [cache], runs [body]
/// with its path, and deletes it afterwards, whatever happens.
Future<T> withTempFile<T>(
  Directory cache,
  Uint8List bytes,
  String extension,
  Future<T> Function(String path) body,
) async {
  final dir = Directory(p.join(cache.path, 'pdf_open'));
  await dir.create(recursive: true);
  final name =
      '${DateTime.now().microsecondsSinceEpoch}'
      '${Random().nextInt(1 << 32)}$extension';
  final file = File(p.join(dir.path, name));
  try {
    await file.writeAsBytes(bytes, flush: true);
    return await body(file.path);
  } finally {
    if (await file.exists()) await file.delete();
  }
}
