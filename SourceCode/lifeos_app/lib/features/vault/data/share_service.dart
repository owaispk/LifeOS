// Share history, bundle templates and the flattened share PDF (PBI-028a).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/painting.dart' show TextDirection;

import '../../../core/log/app_log.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import 'share_pack.dart';

/// Writes [bytes] as [name] into [dir] (emptied first), hands the path to
/// [send], and deletes the folder afterwards, whatever happens: no
/// plaintext stays behind once the share sheet closes (AC2, PBI-024).
Future<void> shareTempFile(
  Uint8List bytes,
  String name,
  Directory dir,
  Future<void> Function(String path) send,
) async {
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  try {
    await file.writeAsBytes(bytes, flush: true);
    await send(file.path);
  } finally {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// The document ids stored in a share event or template.
List<String> idsOf(String json) {
  try {
    return [for (final v in jsonDecode(json) as List) '$v'];
  } catch (_) {
    return const [];
  }
}

class ShareService {
  ShareService(this._repos, {required this.builder, required this.now});

  final Repositories _repos;
  final SharePackBuilder builder;
  final DateTime Function() now;

  /// A document's stored files, in page order.
  Future<List<DocumentFile>> filesOf(String documentId) async =>
      (await _repos.documentFiles.getWhere(
        (f) => f.documentId.equals(documentId),
      ))..sort((a, b) => a.pageNo.compareTo(b.pageNo));

  /// The live document [id] stands for today: a renewed document is
  /// followed to its replacement (AC4). Null if it's gone.
  Future<Document?> current(String id) async {
    final seen = <String>{};
    var doc = await _repos.documents.getById(id);
    while (doc != null && doc.renewedById != null && seen.add(doc.id)) {
      final next = await _repos.documents.getById(doc.renewedById!);
      if (next == null) break;
      doc = next;
    }
    return doc;
  }

  /// [ids] resolved to today's documents, missing ones dropped, no repeats.
  Future<List<Document>> resolve(List<String> ids) async {
    final out = <Document>[];
    for (final id in ids) {
      final d = await current(id);
      if (d != null && out.every((o) => o.id != d.id)) out.add(d);
    }
    return out;
  }

  /// One flattened PDF of [documentIds], in order (AC1, AC3).
  Future<Uint8List> buildPdf(
    List<String> documentIds, {
    Watermark? watermark,
    String? title,
    TextDirection direction = TextDirection.ltr,
    void Function(int done, int total)? onPage,
  }) async {
    final docs = [for (final id in documentIds) await filesOf(id)];
    final sw = Stopwatch()..start();
    final pdf = await builder.build(
      docs.where((d) => d.isNotEmpty).toList(),
      watermark: watermark,
      title: title,
      direction: direction,
      onPage: onPage,
    );
    AppLog.i(
      'share',
      'built ${documentIds.length} docs, watermark ${watermark != null}, '
          '${sw.elapsedMilliseconds} ms (${builder.lastTimings})',
    );
    return pdf;
  }

  /// Adds the history entry for one share (AC5).
  Future<ShareEvent> record({
    required List<String> documentIds,
    String? recipient,
    String? purpose,
    bool watermarked = false,
    String? bundleTitle,
    String kind = 'file',
  }) => _repos.shareEvents.insert(
    ShareEventsCompanion.insert(
      sharedAt: now().millisecondsSinceEpoch,
      documentIds: jsonEncode(documentIds),
      recipient: Value(_blank(recipient)),
      purpose: Value(_blank(purpose)),
      watermarked: Value(watermarked),
      bundleTitle: Value(_blank(bundleTitle)),
      kind: Value(kind),
    ),
  );

  /// Every share, newest first.
  Stream<List<ShareEvent>> watchHistory() => _repos.shareEvents.watchAll().map(
    (l) => l..sort((a, b) => b.sharedAt.compareTo(a.sharedAt)),
  );

  /// How many shares included [documentId].
  Stream<int> watchShareCount(String documentId) =>
      _repos.shareEvents.watchAll().map(
        (l) => l.where((e) => idsOf(e.documentIds).contains(documentId)).length,
      );

  Future<BundleTemplate?> template(String id) =>
      _repos.bundleTemplates.getById(id);

  Stream<List<BundleTemplate>> watchTemplates() => _repos.bundleTemplates
      .watchAll()
      .map((l) => l..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  /// Saves a new template, or updates [id].
  Future<BundleTemplate> saveTemplate(
    String name,
    List<String> documentIds, {
    String? id,
  }) async {
    final ids = Value(jsonEncode(documentIds));
    if (id != null) {
      return _repos.bundleTemplates.update(
        id,
        BundleTemplatesCompanion(name: Value(name.trim()), documentIds: ids),
      );
    }
    final count = (await _repos.bundleTemplates.getAll()).length;
    return _repos.bundleTemplates.insert(
      BundleTemplatesCompanion.insert(
        name: name.trim(),
        documentIds: ids,
        sortOrder: Value(count),
      ),
    );
  }

  Future<void> deleteTemplate(String id) =>
      _repos.bundleTemplates.softDelete(id);

  /// The preset "Job Application Pack": the latest degree, CNIC, CV and
  /// photo in the Vault, in that order (whichever exist).
  Future<List<String>> jobPackSuggestion() async {
    final docs =
        (await _repos.documents.getAll())
            .where((d) => d.archivedAt == null && d.renewedById == null)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    bool titled(Document d, List<String> words) {
      final t = d.title.toLowerCase();
      return words.any(t.contains);
    }

    final picks = <Document?>[
      docs.where((d) => d.docType == 'degree').firstOrNull,
      docs.where((d) => d.docType == 'cnic').firstOrNull,
      docs
          .where((d) => titled(d, const ['cv', 'resume', 'résumé']))
          .firstOrNull,
      docs.where((d) => titled(d, const ['photo', 'picture'])).firstOrNull,
    ];
    return {
      for (final d in picks)
        if (d != null) d.id,
    }.toList();
  }
}

String? _blank(String? s) {
  final t = s?.trim() ?? '';
  return t.isEmpty ? null : t;
}
