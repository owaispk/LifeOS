import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log/app_log.dart';
import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../ai/ai_providers.dart' show entitlementStoreProvider;
import '../settings/settings_providers.dart';
import 'domain/limits.dart';
import 'platform/billing_source.dart';

/// The store. Inert until `main()` swaps the real one in, so a test or
/// the web preview never reaches a billing channel (AC10).
final billingSourceProvider = Provider<BillingSource>((ref) => const NoBilling());

/// **The** premium flag. Everything that gates on Premium reads this and
/// nothing else — Vault, ATC, Settings, and PBI-027a/b when they land.
final premiumProvider = Provider<bool>((ref) {
  // DEV BUILD: Premium always ON for testing. Set to false for production.
  const devPremiumOverride = true;
  if (devPremiumOverride) return true;

  final s = ref.watch(settingsProvider).value;
  return isPremiumAt(s?.premiumUntil, ref.watch(nowProvider)());
});

/// The "N documents left" line, or null when it should not show (AC8).
final documentsLeftProvider = Provider<int?>((ref) {
  final docs = ref.watch(liveDocumentCountProvider).value;
  if (docs == null) return null;
  return documentsLeftToShow(
    premium: ref.watch(premiumProvider),
    liveDocuments: docs,
  );
});

/// Whether one more document can be saved (AC1, AC2).
final canSaveDocumentProvider = Provider<bool>((ref) {
  final docs = ref.watch(liveDocumentCountProvider).value;
  return canSaveDocument(
    premium: ref.watch(premiumProvider),
    liveDocuments: docs ?? 0,
  );
});

/// Live documents in the Vault — archived ones count, trashed ones do
/// not. A count, not a list: the Vault may hold thousands.
final liveDocumentCountProvider = StreamProvider<int>(
  (ref) => ref.watch(repositoriesProvider).documents.watchAll().map((d) => d.length),
);

/// The product as the store describes it, for the Premium screen. Only
/// read when that screen is open — nothing else asks the store (AC10).
final premiumProductProvider = FutureProvider<PremiumProduct?>(
  (ref) => ref.watch(billingSourceProvider).product(),
);

/// Buying, restoring, and keeping the cached entitlement honest.
class PremiumService {
  PremiumService(this._ref);
  final Ref _ref;

  BillingSource get _store => _ref.read(billingSourceProvider);
  DateTime get _now => _ref.read(nowProvider)();

  /// Asks the store what the account owns and caches the answer. A store
  /// that cannot be reached changes nothing: the user keeps what they
  /// had, offline or not (AC5).
  Future<void> refresh({bool force = false}) async {
    final s = _ref.read(settingsProvider).value;
    if (!force && !dueForCheck(s?.premiumCheckedAt, _now)) return;
    final owned = await _store.isSubscribed();
    if (owned == null) {
      AppLog.i('premium', 'store unreachable, keeping cached entitlement');
      return;
    }
    await _write(owned);
  }

  /// The store's own purchase flow. True once the subscription is owned.
  Future<bool> subscribe() async {
    final ok = await _store.subscribe();
    if (ok) await _write(true);
    AppLog.i('premium', ok ? 'subscribed' : 'purchase not completed');
    return ok;
  }

  /// Restore on a new phone, same store account (AC6).
  Future<bool> restore() async {
    final ok = await _store.restore();
    if (ok) await _write(true);
    AppLog.i('premium', ok ? 'restored' : 'nothing to restore');
    return ok;
  }

  Future<void> _write(bool owned) async {
    await _ref
        .read(settingsServiceProvider)
        .update(
          UserSettingsCompanion(
            premiumUntil: Value(owned ? trustedUntil(_now) : null),
            premiumCheckedAt: Value(_now.millisecondsSinceEpoch),
          ),
        );
    // The store's proof of purchase, kept for the managed AI proxy to
    // check (PBI-027b). A credential, so secure storage — never the
    // database, and never a log line.
    final tokens = _ref.read(entitlementStoreProvider);
    final token = owned ? await _store.entitlementToken() : null;
    token == null ? await tokens.clear() : await tokens.write(token);
  }
}

final premiumServiceProvider = Provider<PremiumService>(PremiumService.new);
