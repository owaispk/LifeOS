import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import 'data/capture_service.dart';
import 'ocr/document_analysis.dart';
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
  ),
);

/// Warn before scanning below this much free space (PBI-003 AC6).
const lowStorageMb = 100;

/// Documents captured in this session, waiting to be filed (batch mode),
/// plus where the session was started from (pre-selects folder/person).
class CaptureSession {
  const CaptureSession({
    this.drafts = const [],
    this.folderId,
    this.personId,
    this.renewsDocumentId,
  });

  final List<CaptureDraft> drafts;
  final String? folderId;
  final String? personId;

  /// Set when the session started from "Mark renewed" (PBI-008).
  final String? renewsDocumentId;
}

class CaptureSessionNotifier extends Notifier<CaptureSession> {
  @override
  CaptureSession build() => const CaptureSession();

  void add(
    CaptureDraft draft, {
    String? folderId,
    String? personId,
    String? renewsDocumentId,
  }) {
    final first = state.drafts.isEmpty;
    state = CaptureSession(
      drafts: [...state.drafts, draft],
      folderId: first ? folderId : state.folderId,
      personId: first ? personId : state.personId,
      renewsDocumentId: first ? renewsDocumentId : state.renewsDocumentId,
    );
  }

  /// Drops the draft at the front (saved or discarded).
  void next() {
    final rest = state.drafts.skip(1).toList();
    state = rest.isEmpty
        ? const CaptureSession()
        : CaptureSession(
            drafts: rest,
            folderId: state.folderId,
            personId: state.personId,
            // A renewal applies to the first document only.
          );
  }

  void clear() => state = const CaptureSession();
}

final captureSessionProvider =
    NotifierProvider<CaptureSessionNotifier, CaptureSession>(
      CaptureSessionNotifier.new,
    );
