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
    final pages = await scanner.scan();
    if (pages == null || pages.isEmpty) return; // cancelled

    final checks = await Future.wait(pages.map(CaptureService.checkPage));
    if (checks.any((c) => c.isBlurry)) {
      if (!context.mounted) return;
      final retake = await _ask(
        context,
        key: 'blurry',
        title: context.l10n.cpRetakeTitle,
        body: context.l10n.cpBlurryBody,
        yes: context.l10n.cpRetake,
        no: context.l10n.cpKeepAnyway,
      );
      if (retake) continue;
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
