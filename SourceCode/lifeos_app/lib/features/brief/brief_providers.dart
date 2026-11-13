// Riverpod providers for Daily Voice Brief (PBI-039a).
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../ai/ai_providers.dart';
import '../premium/premium_providers.dart';
import '../score/score_providers.dart';
import '../settings/settings_providers.dart';
import 'domain/brief_data.dart';
import 'domain/brief_service.dart';
import 'platform/tts_service.dart';

export 'domain/brief_data.dart';
export 'domain/brief_service.dart' show BriefConsent, generatePlainTextBrief;
export 'platform/tts_service.dart';

/// Live brief data, recomputed whenever underlying data changes.
final briefDataProvider = FutureProvider<BriefData>((ref) async {
  // Watch dependencies to trigger recomputation
  ref.watch(settingsProvider);

  return computeBriefData(
    repos: ref.watch(repositoriesProvider),
    now: ref.watch(nowProvider)(),
    weights: ref.watch(scoreWeightsProvider),
  );
});

/// The TTS service instance. Overridden in `main()` with the real one.
final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());

/// Brief consent setting (separate from document AI consent).
final briefConsentProvider = Provider<BriefConsent>((ref) {
  final s = ref.watch(settingsProvider).value;
  return BriefConsent.parse(s?.briefConsent);
});

/// Whether brief AI is available (premium + configured + consent).
final briefAiAvailableProvider = Provider<bool>((ref) {
  final premium = ref.watch(premiumProvider);
  final settings = ref.watch(aiSettingsProvider).value;
  final consent = ref.watch(briefConsentProvider);
  return premium &&
      (settings?.isConfigured ?? false) &&
      consent != BriefConsent.never;
});

/// Brief settings from user_settings.
class BriefSettings {
  const BriefSettings({
    this.briefTime = const Duration(hours: 7, minutes: 30),
    this.ttsRate = 0.85,  // Slower default for better clarity
    this.briefConsent = BriefConsent.ask,
    this.briefEnabled = true,
  });

  /// Time of day for the morning brief notification.
  final Duration briefTime;

  /// TTS speech rate (0.5–1.5).
  final double ttsRate;

  /// Brief AI consent.
  final BriefConsent briefConsent;

  /// Whether brief notifications are enabled.
  final bool briefEnabled;

  BriefSettings copyWith({
    Duration? briefTime,
    double? ttsRate,
    BriefConsent? briefConsent,
    bool? briefEnabled,
  }) => BriefSettings(
    briefTime: briefTime ?? this.briefTime,
    ttsRate: ttsRate ?? this.ttsRate,
    briefConsent: briefConsent ?? this.briefConsent,
    briefEnabled: briefEnabled ?? this.briefEnabled,
  );
}

final briefSettingsProvider = Provider<BriefSettings>((ref) {
  final s = ref.watch(settingsProvider).value;
  Duration parseTime(String? hm) {
    if (hm == null || !hm.contains(':')) {
      return const Duration(hours: 7, minutes: 30);
    }
    final parts = hm.split(':');
    return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
  }

  return BriefSettings(
    briefTime: parseTime(s?.briefTime),
    ttsRate: s?.ttsRate ?? 0.85,
    briefConsent: BriefConsent.parse(s?.briefConsent),
    briefEnabled: s?.briefEnabled ?? true,
  );
});

/// Service for updating brief settings.
class BriefSettingsService {
  const BriefSettingsService(this._ref);
  final Ref _ref;

  Future<void> setBriefTime(Duration time) async {
    final hm =
        '${time.inHours.toString().padLeft(2, '0')}:'
        '${(time.inMinutes % 60).toString().padLeft(2, '0')}';
    await _ref.read(settingsServiceProvider).update(
      UserSettingsCompanion(briefTime: drift.Value(hm)),
    );
  }

  Future<void> setTtsRate(double rate) async {
    await _ref.read(settingsServiceProvider).update(
      UserSettingsCompanion(ttsRate: drift.Value(rate.clamp(0.5, 1.5))),
    );
  }

  Future<void> setBriefConsent(BriefConsent consent) async {
    await _ref.read(settingsServiceProvider).update(
      UserSettingsCompanion(briefConsent: drift.Value(consent.name)),
    );
  }

  Future<void> setBriefEnabled(bool enabled) async {
    await _ref.read(settingsServiceProvider).update(
      UserSettingsCompanion(briefEnabled: drift.Value(enabled)),
    );
  }
}

final briefSettingsServiceProvider = Provider<BriefSettingsService>(
  BriefSettingsService.new,
);

/// Generates the brief text (AI or plain).
final briefTextProvider = FutureProvider<String>((ref) async {
  final data = await ref.watch(briefDataProvider.future);
  final aiAvailable = ref.watch(briefAiAvailableProvider);
  final consent = ref.watch(briefConsentProvider);

  // Use AI only if available and consented
  if (aiAvailable && consent == BriefConsent.always) {
    final settings = await ref.watch(aiSettingsProvider.future);
    final now = ref.watch(nowProvider)();
    final isMorning = now.hour >= 5 && now.hour < 12;

    final aiBrief = await generateAiBrief(
      data: data,
      settings: settings,
      isMorning: isMorning,
    );

    if (aiBrief != null) return aiBrief;
  }

  // Fallback to plain text
  return generatePlainTextBrief(data);
});
