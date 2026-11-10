// Device services used by capture (PBI-003), behind interfaces so the
// whole flow is testable without a camera, file picker or share sheet.
import 'dart:async';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// A file handed to LifeOS (picked or shared in).
class IncomingFile {
  const IncomingFile(this.path, {this.mime});
  final String path;
  final String? mime;

  bool get isPdf =>
      mime == 'application/pdf' || path.toLowerCase().endsWith('.pdf');
}

abstract interface class DocumentScanner {
  /// Opens the native scanner. Returns page image paths in capture order,
  /// or null/empty if the user cancelled.
  Future<List<String>?> scan();
}

abstract interface class FileImporter {
  /// Lets the user pick images or PDFs. Empty if cancelled.
  Future<List<IncomingFile>> pick();
}

abstract interface class StorageInfo {
  /// Free space in MB, or null if unknown.
  Future<double?> freeMb();
}

/// What another app shared into LifeOS: files, or plain text — never
/// both. A share carrying any image or PDF is a document share and its
/// text is dropped, so "share a photo with a caption" keeps working as it
/// did (PBI-034 AC5).
class SharedIn {
  const SharedIn({this.files = const [], this.text = ''});

  static const none = SharedIn();

  final List<IncomingFile> files;

  /// Plain text or a URL, joined by newlines when several were shared.
  final String text;

  bool get isEmpty => files.isEmpty && text.trim().isEmpty;
}

abstract interface class ShareInbox {
  /// Shared into the app while it's running.
  Stream<SharedIn> get incoming;

  /// What launched the app, if a share did.
  Future<SharedIn> initial();

  /// Marks the share as handled.
  Future<void> reset();
}

// ─────────────────────────── Real implementations ──────────────────────────

class NativeDocumentScanner implements DocumentScanner {
  const NativeDocumentScanner();

  @override
  Future<List<String>?> scan() => CunningDocumentScanner.getPictures(
    noOfPages: 20,
    // The ML Kit scanner's own "import from gallery" stays off; LifeOS has
    // a separate Import action.
    androidScannerMode: AndroidScannerMode.full,
  );
}

class PickerFileImporter implements FileImporter {
  const PickerFileImporter();

  @override
  Future<List<IncomingFile>> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    return [
      for (final f in files)
        if (f.path != null) IncomingFile(f.path!),
    ];
  }
}

class DeviceStorageInfo implements StorageInfo {
  const DeviceStorageInfo();

  @override
  Future<double?> freeMb() async {
    try {
      return await DiskSpacePlus().getFreeDiskSpace;
    } on Object {
      return null; // unknown → don't block scanning
    }
  }
}

/// What the share plugin handed over, as files or as text. A share
/// carrying any image or PDF is a document share and its text is dropped,
/// so "photo with a caption" keeps going to capture (PBI-034 AC5).
SharedIn mapSharedMedia(List<SharedMediaFile> items) {
  final files = [
    for (final f in items)
      if (f.type == SharedMediaType.image || f.type == SharedMediaType.file)
        IncomingFile(f.path, mime: f.mimeType),
  ];
  if (files.isNotEmpty) return SharedIn(files: files);
  // For text and url shares the plugin puts the content in `path`.
  final text = [
    for (final f in items)
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url)
        f.path,
  ].join('\n').trim();
  return SharedIn(text: text);
}

class IntentShareInbox implements ShareInbox {
  const IntentShareInbox();

  @override
  Stream<SharedIn> get incoming =>
      ReceiveSharingIntent.instance.getMediaStream().map(mapSharedMedia);

  @override
  Future<SharedIn> initial() async =>
      mapSharedMedia(await ReceiveSharingIntent.instance.getInitialMedia());

  @override
  Future<void> reset() async => ReceiveSharingIntent.instance.reset();
}

/// Inert services for the web preview and before setup.
class NoCapture
    implements DocumentScanner, FileImporter, StorageInfo, ShareInbox {
  const NoCapture();

  @override
  Future<List<String>?> scan() async => null;

  @override
  Future<List<IncomingFile>> pick() async => const [];

  @override
  Future<double?> freeMb() async => null;

  @override
  Stream<SharedIn> get incoming => const Stream.empty();

  @override
  Future<SharedIn> initial() async => SharedIn.none;

  @override
  Future<void> reset() async {}
}
