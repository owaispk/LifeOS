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

abstract interface class ShareInbox {
  /// Files shared into the app while it's running.
  Stream<List<IncomingFile>> get incoming;

  /// Files that launched the app.
  Future<List<IncomingFile>> initial();

  /// Marks the shared files as handled.
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

class IntentShareInbox implements ShareInbox {
  const IntentShareInbox();

  static List<IncomingFile> _map(List<SharedMediaFile> files) => [
    for (final f in files)
      if (f.type == SharedMediaType.image || f.type == SharedMediaType.file)
        IncomingFile(f.path, mime: f.mimeType),
  ];

  @override
  Stream<List<IncomingFile>> get incoming =>
      ReceiveSharingIntent.instance.getMediaStream().map(_map);

  @override
  Future<List<IncomingFile>> initial() async =>
      _map(await ReceiveSharingIntent.instance.getInitialMedia());

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
  Stream<List<IncomingFile>> get incoming => const Stream.empty();

  @override
  Future<List<IncomingFile>> initial() async => const [];

  @override
  Future<void> reset() async {}
}
