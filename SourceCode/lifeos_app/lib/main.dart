import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/data_providers.dart';
import 'features/atc/data/atc_service.dart';
import 'features/vault/data/expiry_guard.dart';
import 'features/capture/capture_providers.dart';
import 'features/capture/ocr/document_analysis.dart';
import 'features/capture/platform/capture_platform.dart';
import 'features/reminders/data/reminder_service.dart';
import 'features/reminders/platform/local_notifications_gateway.dart';
import 'features/reminders/reminder_providers.dart';
import 'features/reminders/reminder_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The web build is a UI preview only for now: Drift on web needs the
  // sqlite3.wasm/worker assets, which are not part of the MVP.
  final repos = kIsWeb ? null : await openLocalData();

  // Auto Task Creator (PBI-013): keep one next occurrence per rule — at
  // start and whenever the app comes back to the foreground.
  if (repos != null) {
    final atc = AtcService(repos);
    await atc.generateAll();
    AppLifecycleListener(onResume: atc.generateAll);
    // Expiry Guard (PBI-008): renewal tasks + ladder reminders follow
    // document expiry dates; the weekly nudge is rebuilt on resume.
    final guard = ExpiryGuard(repos);
    await guard.start();
    AppLifecycleListener(onResume: guard.reconcile);
  }

  // Local notifications (PBI-012) on phones only.
  final isPhone =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  LocalNotificationsGateway? gateway;
  if (repos != null && isPhone) {
    gateway = LocalNotificationsGateway();
    await gateway.init(ReminderService(repos).handleAction);
    final sync = ReminderSync(repos, gateway);
    await sync.start();
    AppLifecycleListener(onResume: sync.onResume);
  }

  // Vault files live in the app's private documents folder (PBI-003).
  final vaultRoot = repos == null
      ? null
      : Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'vault'),
        );

  runApp(
    ProviderScope(
      overrides: [
        if (repos != null) repositoriesProvider.overrideWithValue(repos),
        if (gateway != null)
          notificationGatewayProvider.overrideWithValue(gateway),
        if (vaultRoot != null) vaultRootProvider.overrideWithValue(vaultRoot),
        if (isPhone) ...[
          documentScannerProvider.overrideWithValue(
            const NativeDocumentScanner(),
          ),
          fileImporterProvider.overrideWithValue(const PickerFileImporter()),
          storageInfoProvider.overrideWithValue(const DeviceStorageInfo()),
          shareInboxProvider.overrideWithValue(const IntentShareInbox()),
          textReaderProvider.overrideWithValue(const MlKitTextReader()),
        ],
      ],
      child: const LifeOsApp(),
    ),
  );
}
