import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log/app_log.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../capture/ocr/doc_classifier.dart' show Classification;
import '../capture/ocr/field_extractor.dart' show Extracted;
import '../premium/premium_providers.dart';
import '../settings/settings_providers.dart';
import 'domain/ai_gate.dart';
import 'domain/extraction_contract.dart';
import 'platform/llm_provider.dart';
import 'platform/secret_store.dart';

export 'domain/ai_gate.dart' show AiConsent, AiGate;
export 'platform/llm_provider.dart' show AiFailure;

/// Where the API key lives. `main()` swaps the secure one in.
final aiSecretStoreProvider = Provider<SecretStore>(
  (ref) => MemorySecretStore(),
);

/// Builds the provider for the user's settings, or null when nothing is
/// configured. Overridden in tests with a fake.
final llmProviderFactoryProvider =
    Provider<LlmProvider? Function(AiSettings)>(
      (ref) => (s) => s.isConfigured
          ? OpenAiCompatProvider(
              baseUrl: s.baseUrl!,
              apiKey: s.apiKey,
              model: s.model!,
            )
          : null,
    );

/// The user's AI configuration. The key is read from secure storage, so
/// this is a future, not a plain read of the settings row.
class AiSettings {
  const AiSettings({
    this.baseUrl,
    this.model,
    this.apiKey = '',
    this.consent = AiConsent.ask,
  });

  final String? baseUrl;
  final String? model;

  /// Empty is legitimate: a local Ollama needs no key.
  final String apiKey;
  final AiConsent consent;

  bool get isConfigured =>
      (baseUrl?.trim().isNotEmpty ?? false) &&
      (model?.trim().isNotEmpty ?? false);

  /// Whether a key has been stored, without handing the key around.
  bool get hasKey => apiKey.isNotEmpty;
}

final aiSettingsProvider = FutureProvider<AiSettings>((ref) async {
  final s = ref.watch(settingsProvider).value;
  final key = await ref.watch(aiSecretStoreProvider).read();
  return AiSettings(
    baseUrl: s?.aiBaseUrl,
    model: s?.aiModel,
    apiKey: key ?? '',
    consent: AiConsent.parse(s?.aiConsent),
  );
});

/// Reading and writing the AI configuration.
class AiSettingsService {
  const AiSettingsService(this._ref);
  final Ref _ref;

  Future<void> setProvider({
    required String? baseUrl,
    required String? model,
    String? apiKey,
  }) async {
    await _ref
        .read(settingsServiceProvider)
        .update(
          UserSettingsCompanion(
            aiBaseUrl: Value(_blankToNull(baseUrl)),
            aiModel: Value(_blankToNull(model)),
          ),
        );
    if (apiKey != null) {
      final store = _ref.read(aiSecretStoreProvider);
      // Never written to the database — secure storage only (AC6).
      apiKey.trim().isEmpty
          ? await store.clear()
          : await store.write(apiKey.trim());
    }
    _ref.invalidate(aiSettingsProvider);
  }

  Future<void> setConsent(AiConsent consent) async {
    await _ref
        .read(settingsServiceProvider)
        .update(UserSettingsCompanion(aiConsent: Value(consent.name)));
    _ref.invalidate(aiSettingsProvider);
  }

  static String? _blankToNull(String? s) =>
      s == null || s.trim().isEmpty ? null : s.trim();
}

final aiSettingsServiceProvider = Provider<AiSettingsService>(
  AiSettingsService.new,
);

/// What the AI added to a document, if anything.
class AiResult {
  const AiResult({required this.type, required this.fields});

  final String type;

  /// Field values, already validated — safe to show and store.
  final Map<String, String> fields;
}

/// Runs the cloud step, when the gate allows it (PBI-027a).
///
/// Nothing here decides policy: [aiGate] does. This only caches, calls
/// and merges — and never throws at its caller, because the on-device
/// result must survive any provider failure (AC5, AC8).
class AiEnrichment {
  const AiEnrichment(this._ref);
  final Ref _ref;

  /// The gate for a document that has just been read on-device.
  Future<AiGate> gateFor(Classification classification, String text) async {
    final settings = await _ref.read(aiSettingsProvider.future);
    return aiGate(
      AiGateInput(
        classification: classification,
        premium: _ref.read(premiumProvider),
        configured: settings.isConfigured,
        consent: settings.consent,
        hasText: text.trim().isNotEmpty,
      ),
    );
  }

  /// Sends [text] and returns what came back, or null when the call did
  /// not produce anything usable. A cached answer for the same text is
  /// returned without a call (AC3).
  Future<AiResult?> enrich(String text, {List<String> hints = const []}) async {
    final cached = await _readCache(text);
    if (cached != null) {
      AppLog.i('ai', 'cache hit, no call made');
      return cached;
    }
    final settings = await _ref.read(aiSettingsProvider.future);
    final provider = _ref.read(llmProviderFactoryProvider)(settings);
    if (provider == null) return null;
    try {
      final extraction = await provider.extract(text, hints: hints);
      final result = AiResult(
        type: extraction.type,
        fields: extraction.fields,
      );
      await _writeCache(text, result);
      AppLog.i('ai', 'provider answered');
      return result;
    } on AiFailure {
      rethrow; // the caller shows the provider's own message
    } on Object catch (e) {
      AppLog.w('ai', 'call failed: ${e.runtimeType}');
      return null;
    }
  }

  // ── Cache, keyed by text hash + prompt version ──────────────────────

  String _key(String text) => 'ai_cache:v$promptVersion:${textHash(text)}';

  Future<AiResult?> _readCache(String text) async {
    final db = _ref.read(repositoriesProvider).db;
    final row = await (db.select(
      db.appMeta,
    )..where((m) => m.key.equals(_key(text)))).getSingleOrNull();
    if (row == null) return null;
    try {
      final json = jsonDecode(row.value) as Map<String, Object?>;
      return AiResult(
        type: json['type'] as String? ?? 'other',
        fields: {
          for (final e in (json['fields'] as Map? ?? {}).entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        },
      );
    } on Object {
      return null; // a corrupt cache row is simply a miss
    }
  }

  Future<void> _writeCache(String text, AiResult result) async {
    final db = _ref.read(repositoriesProvider).db;
    await db
        .into(db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(
            key: _key(text),
            value: jsonEncode({'type': result.type, 'fields': result.fields}),
          ),
        );
  }
}

final aiEnrichmentProvider = Provider<AiEnrichment>(AiEnrichment.new);

/// AI values as the confirm screen wants them, marked so the UI can
/// badge them. Only fills what on-device left empty: the user's own
/// corrections and a confident on-device read always win.
Map<String, Extracted> mergeAiFields(
  Map<String, Extracted> onDevice,
  Map<String, String> fromAi,
) => {
  ...onDevice,
  for (final e in fromAi.entries)
    if ((onDevice[e.key]?.value ?? '').isEmpty)
      e.key: Extracted(e.value, aiFieldConfidence),
};

/// Marks a value as AI-read. Distinct from any on-device confidence, so
/// the badge cannot be faked by a lucky local score.
const aiFieldConfidence = -1.0;

bool isAiRead(Extracted? e) => e?.confidence == aiFieldConfidence;
