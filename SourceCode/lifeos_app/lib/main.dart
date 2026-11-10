import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/log/app_log.dart';
import 'core/log/diagnostics.dart';
import 'data/data_providers.dart';
import 'features/calendar/calendar_providers.dart';
import 'features/premium/premium_providers.dart';
import 'features/premium/platform/billing_source.dart';
import 'features/calendar/platform/calendar_source.dart';
import 'features/atc/data/atc_service.dart';
import 'features/vault/data/expiry_guard.dart';
import 'features/capture/capture_providers.dart';
import 'features/capture/ocr/document_analysis.dart';
import 'features/capture/platform/capture_platform.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/reminders/data/reminder_service.dart';
import 'features/reminders/platform/local_notifications_gateway.dart';
import 'features/reminders/reminder_providers.dart';
import 'features/reminders/reminder_sync.dart';
import 'features/score/data/score_service.dart';
import 'features/security/crypto/vault_crypto.dart';
import 'features/security/crypto/vault_files.dart';
import 'features/security/lock_gate.dart';
import 'features/security/security_providers.dart';
import 'features/settings/settings_providers.dart' show applyRegion;
import 'features/score/domain/life_score.dart';
import 'features/score/score_providers.dart';
import 'features/tasks/ui/quick_parse.dart';
import 'features/widget/platform/widget_gateway.dart';
import 'features/widget/widget_providers.dart';
import 'features/widget/widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Diagnostics log first (PBI-030), so start-up problems are recorded.
  // It lives in the app's private folder; nothing leaves the phone unless
  // the user shares it from Settings → Diagnostics.
  if (!kIsWeb) {
    final support = await getApplicationSupportDirectory();
    await AppLog.init(Directory(p.join(support.path, 'logs')));
  }
  captureErrors();
  LogLifecycle();
  final facts = await deviceFacts();
  AppLog.i('app', 'start ${facts.values.join(' · ')}');

  // The web build is a UI preview only for now: Drift on web needs the
  // sqlite3.wasm/worker assets, which are not part of the MVP.
  final repos = kIsWeb ? null : await openLocalData();
  // Region formats before anything below writes amounts or dates into
  // generated text (Auto Task titles, reminders) — PBI-035.
  if (repos != null) {
    applyRegion((await repos.userSettings.getAll()).firstOrNull);
  }

  // Life Score weights ship as a version-pinned file (PBI-020).
  final weights = ScoreWeights.fromJson(
    await rootBundle.loadString('assets/score_weights.json'),
  );

  // Files at rest are AES-256-GCM (PBI-024); Sprint 1-5 files are
  // encrypted in place once. The Master Key lives in the device keystore.
  const keyStore = SecureKeyStore();
  if (repos != null) {
    final encrypted = await VaultFiles(repos, VaultCrypto(keyStore)).migrate();
    if (encrypted > 0) AppLog.i('vault', 'encrypted $encrypted older files');
    await skipOnboardingForExistingData(repos);
  }

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
    // Life Score (PBI-020): today's snapshot at start and on resume, after
    // the generators above have run. Pull-to-refresh on Home redoes it.
    final score = ScoreService(repos, weights: weights);
    await score.refresh();
    AppLifecycleListener(onResume: score.refresh);
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

  // Home-screen widget (PBI-033): Android first-class. The widget is
  // pushed fresh data on every relevant change and on app pause.
  WidgetGateway? widgetGateway;
  if (repos != null && defaultTargetPlatform == TargetPlatform.android) {
    widgetGateway = const HomeWidgetGateway();
    final widgets = WidgetSync(repos, widgetGateway, weights: weights);
    await widgets.start();
    AppLifecycleListener(onPause: widgets.onPause);
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
        scoreWeightsProvider.overrideWithValue(weights),
        if (repos != null) repositoriesProvider.overrideWithValue(repos),
        if (gateway != null)
          notificationGatewayProvider.overrideWithValue(gateway),
        if (widgetGateway != null)
          widgetGatewayProvider.overrideWithValue(widgetGateway),
        if (vaultRoot != null) vaultRootProvider.overrideWithValue(vaultRoot),
        if (isPhone) ...[
          keyStoreProvider.overrideWithValue(keyStore),
          authenticatorProvider.overrideWithValue(LocalAuthenticator()),
          documentScannerProvider.overrideWithValue(
            const NativeDocumentScanner(),
          ),
          fileImporterProvider.overrideWithValue(const PickerFileImporter()),
          storageInfoProvider.overrideWithValue(const DeviceStorageInfo()),
          shareInboxProvider.overrideWithValue(const IntentShareInbox()),
          textReaderProvider.overrideWithValue(const MlKitTextReader()),
          // Voice capture (PBI-010): without this the overlay gets
          // NoSpeechInput and always says "Voice isn't available".
          speechInputProvider.overrideWithValue(DeviceSpeechInput()),
          // Device calendar (PBI-032). Inert elsewhere, and this one asks
          // for nothing until the user turns events on in Settings.
          calendarSourceProvider.overrideWithValue(DeviceCalendarSource()),
          // Store billing (PBI-029). The plugin wants to be listened to
          // from launch or purchases made outside the app are missed.
          billingSourceProvider.overrideWithValue(StoreBilling()),
        ],
      ],
      child: const LifeOsApp(),
    ),
  );
}
