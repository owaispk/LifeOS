// Test doubles for device-only services.
import 'dart:async';
import 'dart:io';

import 'package:lifeos_app/features/capture/ocr/document_analysis.dart';
import 'package:lifeos_app/features/capture/platform/capture_platform.dart';
import 'package:lifeos_app/features/reminders/domain/reminder_planner.dart';
import 'package:lifeos_app/features/reminders/platform/notification_gateway.dart';

/// Records what would be scheduled on the phone.
class FakeGateway implements NotificationGateway {
  List<PlannedNotification> scheduled = [];
  int permissionRequests = 0;
  int timezoneRefreshes = 0;

  @override
  Future<void> init(NotificationActionCallback onAction) async {}

  @override
  Future<void> refreshTimezone() async => timezoneRefreshes++;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> replaceAll(List<PlannedNotification> planned) async =>
      scheduled = planned;
}

/// Scanner returning queued results (null = user cancelled).
class FakeScanner implements DocumentScanner {
  final results = <List<String>?>[];
  int calls = 0;

  @override
  Future<List<String>?> scan() async {
    calls++;
    return results.isEmpty ? null : results.removeAt(0);
  }
}

class FakeImporter implements FileImporter {
  List<IncomingFile> next = const [];

  @override
  Future<List<IncomingFile>> pick() async => next;
}

class FakeStorage implements StorageInfo {
  FakeStorage([this.mb]);
  double? mb;

  @override
  Future<double?> freeMb() async => mb;
}

class FakeShareInbox implements ShareInbox {
  final controller = StreamController<List<IncomingFile>>.broadcast();
  List<IncomingFile> atLaunch = const [];
  int resets = 0;

  @override
  Stream<List<IncomingFile>> get incoming => controller.stream;

  @override
  Future<List<IncomingFile>> initial() async => atLaunch;

  @override
  Future<void> reset() async => resets++;
}

/// "OCR" that returns queued text (empty when nothing is queued).
class FakeTextReader implements TextReader {
  final texts = <String>[];

  @override
  Future<String> read(List<String> imagePaths) async =>
      texts.isEmpty ? '' : texts.removeAt(0);
}

/// All capture fakes plus a real temp folder for Vault files.
class CaptureFakes {
  CaptureFakes(this.vaultRoot);
  final Directory vaultRoot;
  final scanner = FakeScanner();
  final importer = FakeImporter();
  final storage = FakeStorage();
  final inbox = FakeShareInbox();
  final reader = FakeTextReader();
}
