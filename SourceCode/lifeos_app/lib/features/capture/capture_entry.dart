import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import 'capture_providers.dart';
import 'data/capture_service.dart';
import 'platform/capture_platform.dart';

const captureRoute = '/capture';

/// Single entry point for every "Scan" button (Vault, FAB, empty states).
///
/// 1. Warns when free space is under [lowStorageMb] (AC6).
/// 2. Opens the native scanner.
/// 3. Offers "Retake?" when a page looks blurry (AC5).
/// 4. Adds the scan to the session and opens Review & file (batch mode).
///
/// [folderId]/[personId] pre-select where the document will be filed.
Future<void> startScan(
  BuildContext context, {
  String? folderId,
  String? personId,
  String? renewsDocumentId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);

  final free = await container.read(storageInfoProvider).freeMb();
  if (free != null && free < lowStorageMb) {
    if (!context.mounted) return;
    final go = await _ask(
      context,
      key: 'low-storage',
      title: context.l10n.cpStorageFullTitle,
      body: context.l10n.cpStorageFullBody('${free.floor()}'),
      yes: context.l10n.cpScanAnyway,
      no: context.l10n.cancel,
    );
    if (!go) return;
  }

  final scanner = container.read(documentScannerProvider);
  while (true) {
    var pages = await scanner.scan();
    if (pages == null || pages.isEmpty) return; // cancelled

    final checks = await Future.wait(pages.map(CaptureService.checkPage));
    final blurry = [
      for (var i = 0; i < checks.length; i++)
        if (checks[i].isBlurry) i,
    ];
    if (blurry.isNotEmpty) {
      if (!context.mounted) return;
      // Dismissing the dialog keeps the scan, as before.
      final choice = await _askBlurry(context, blurry, pages.length);
      if (choice == _BlurChoice.retake) continue;
      if (choice == _BlurChoice.drop) {
        pages = [
          for (var i = 0; i < pages.length; i++)
            if (!blurry.contains(i)) pages[i],
        ];
      }
    }

    container
        .read(captureSessionProvider.notifier)
        .add(
          CaptureDraft.scan(pages),
          folderId: folderId,
          personId: personId,
          renewsDocumentId: renewsDocumentId,
        );
    if (context.mounted) _openReview(context);
    return;
  }
}

/// "Import from files": images become one document, each PDF its own.
Future<void> importFiles(
  BuildContext context, {
  String? folderId,
  String? personId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final files = await container.read(fileImporterProvider).pick();
  if (files.isEmpty) return;
  addIncoming(
    container,
    files,
    source: 'import',
    folderId: folderId,
    personId: personId,
  );
  if (context.mounted) _openReview(context);
}

/// Queues picked or shared files as drafts.
void addIncoming(
  ProviderContainer container,
  List<IncomingFile> files, {
  required String source,
  String? folderId,
  String? personId,
}) {
  final session = container.read(captureSessionProvider.notifier);
  final images = [
    for (final f in files)
      if (!f.isPdf) f.path,
  ];
  for (final pdf in files.where((f) => f.isPdf)) {
    session.add(
      CaptureDraft.importPdf(pdf.path, source: source),
      folderId: folderId,
      personId: personId,
    );
  }
  if (images.isNotEmpty) {
    session.add(
      CaptureDraft.importImages(images, source: source),
      folderId: folderId,
      personId: personId,
    );
  }
}

void _openReview(BuildContext context) {
  final router = GoRouter.of(context);
  if (router.state.matchedLocation != captureRoute) {
    router.push(captureRoute);
  }
}

enum _BlurChoice { retake, keep, drop }

/// "Retake?" naming the unclear pages (AC5). In a multi-page scan the
/// sharp pages can be kept and only the unclear ones removed.
Future<_BlurChoice?> _askBlurry(
  BuildContext context,
  List<int> blurry,
  int pageCount,
) {
  final l = context.l10n;
  final names = blurry.map((i) => '${i + 1}').join(', ');
  final canDrop = blurry.length < pageCount;
  return showDialog<_BlurChoice>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('dialog-blurry'),
      title: Text(l.cpRetakeTitle),
      content: Text(
        pageCount == 1 ? l.cpBlurryBody : l.cpBlurryPageBody(names),
      ),
      actions: [
        TextButton(
          key: const ValueKey('blurry-no'),
          onPressed: () => Navigator.pop(context, _BlurChoice.keep),
          child: Text(l.cpKeepAnyway),
        ),
        if (canDrop)
          TextButton(
            key: const ValueKey('blurry-drop'),
            onPressed: () => Navigator.pop(context, _BlurChoice.drop),
            child: Text(l.cpDropPage(names)),
          ),
        FilledButton(
          key: const ValueKey('blurry-yes'),
          onPressed: () => Navigator.pop(context, _BlurChoice.retake),
          child: Text(l.cpRetake),
        ),
      ],
    ),
  );
}

Future<bool> _ask(
  BuildContext context, {
  required String key,
  required String title,
  required String body,
  required String yes,
  required String no,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: ValueKey('dialog-$key'),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          key: ValueKey('$key-no'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(no),
        ),
        FilledButton(
          key: ValueKey('$key-yes'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return answer == true;
}
