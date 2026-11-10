// Test doubles for device-only services.
import 'dart:async';
import 'dart:io';

import 'package:lifeos_app/features/calendar/platform/calendar_source.dart';
import 'package:lifeos_app/features/capture/ocr/document_analysis.dart';
import 'package:lifeos_app/features/premium/platform/billing_source.dart';
import 'package:lifeos_app/features/capture/platform/capture_platform.dart';
import 'package:lifeos_app/features/reminders/domain/reminder_planner.dart';
import 'package:lifeos_app/features/reminders/platform/notification_gateway.dart';
import 'package:lifeos_app/features/security/lock_gate.dart';

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
  final controller = StreamController<SharedIn>.broadcast();

  /// What the share that launched the app carried.
  SharedIn atLaunch = SharedIn.none;
  int resets = 0;

  /// Shares a list of files, as another app would.
  void share(List<IncomingFile> files) =>
      controller.add(SharedIn(files: files));

  /// Shares plain text, as WhatsApp or Messages would (PBI-034).
  void shareText(String text) => controller.add(SharedIn(text: text));

  @override
  Stream<SharedIn> get incoming => controller.stream;

  @override
  Future<SharedIn> initial() async => atLaunch;

  @override
  Future<void> reset() async => resets++;
}

/// "OCR" that returns queued text (empty when nothing is queued).
class FakeTextReader implements TextReader {
  final texts = <String>[];

  /// Makes the next read throw, like ML Kit's native failure on device.
  Object? failWith;

  @override
  Future<String> read(List<String> imagePaths) async {
    final error = failWith;
    if (error != null) throw error;
    return texts.isEmpty ? '' : texts.removeAt(0);
  }
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

/// Biometric / PIN stand-in (PBI-024).
class FakeAuthenticator implements Authenticator {
  FakeAuthenticator({this.available = true, this.pass = true});
  bool available;
  bool pass;
  int asks = 0;

  @override
  Future<bool> canAuthenticate() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    asks++;
    return pass;
  }
}

/// A device calendar that is not a device (PBI-032). Counts every call,
/// so a test can prove nothing touches the calendar while the feature is
/// off (AC5).
class FakeCalendar implements CalendarSource {
  FakeCalendar({this.permission = false, this.grants = true});

  /// Whether the permission is already granted.
  bool permission;

  /// What the in-context prompt answers.
  bool grants;

  /// Calendars this "phone" has.
  List<DeviceCal> cals = const [];

  /// Events the calendars hold; filtered by range and calendar on read.
  List<CalEvent> events = const [];

  /// Makes the next read throw, like a calendar store that is unavailable.
  Object? failWith;

  int asks = 0;
  int reads = 0;
  int permissionChecks = 0;

  /// Every call that would reach the platform.
  int get calls => asks + reads + permissionChecks;

  @override
  Future<bool> hasPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<bool> requestPermission() async {
    asks++;
    return permission = grants;
  }

  @override
  Future<List<DeviceCal>> calendars() async {
    reads++;
    return permission ? cals : const [];
  }

  @override
  Future<List<CalEvent>> eventsBetween(
    DateTime from,
    DateTime to, {
    required List<DeviceCal> calendars,
  }) async {
    reads++;
    final error = failWith;
    if (error != null) throw error;
    final ids = {for (final c in calendars) c.id};
    return [
      for (final e in events)
        if (ids.contains(e.calendarId) &&
            e.start.isBefore(to) &&
            !e.end.isBefore(from))
          e,
    ];
  }
}

/// A store that is not a store (PBI-029). Counts every call, so a test
/// can prove nothing reaches billing unless the user asked for it (AC10).
class FakeBilling implements BillingSource {
  FakeBilling({this.owned = false, this.available = true});

  /// Does the store account own the subscription?
  bool owned;
  bool available;

  /// Null makes [isSubscribed] answer "could not ask" (AC5).
  bool? reachable = true;

  /// What the store charges, already formatted as a store would.
  PremiumProduct? offer = const PremiumProduct(
    id: premiumProductId,
    price: 'Rs 450.00',
    title: 'LifeOS Premium',
  );

  /// Whether the next purchase attempt succeeds.
  bool purchaseSucceeds = true;

  int asks = 0;
  int purchases = 0;
  int restores = 0;
  int productLookups = 0;

  /// Every call that would reach the billing SDK.
  int get calls => asks + purchases + restores + productLookups;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<PremiumProduct?> product() async {
    productLookups++;
    return available ? offer : null;
  }

  @override
  Future<bool?> isSubscribed() async {
    asks++;
    if (reachable != true) return null;
    return owned;
  }

  @override
  Future<bool> subscribe() async {
    purchases++;
    if (!purchaseSucceeds) return false;
    return owned = true;
  }

  @override
  Future<bool> restore() async {
    restores++;
    if (reachable != true) return false;
    return owned;
  }

  /// What the store would hand over as proof of purchase.
  String token = 'play-purchase-token-xyz';

  @override
  Future<String?> entitlementToken() async => owned ? token : null;
}
