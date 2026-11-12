// Store billing, behind an interface (PBI-029) so the paywall, the
// limits and the entitlement are all testable without a store.
//
// There is no LifeOS server and no account: entitlement is whatever the
// store says the signed-in store account owns right now.
import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/log/app_log.dart';

/// The subscription product id, as configured in Play Console and App
/// Store Connect.
const premiumProductId = 'lifeos_premium_monthly';

/// The subscription as the store describes it. [price] is already
/// formatted in the store's own currency — never build this yourself.
class PremiumProduct {
  const PremiumProduct({required this.id, required this.price, this.title = ''});

  final String id;
  final String price;
  final String title;
}

abstract interface class BillingSource {
  /// Whether the store is usable at all on this device.
  Future<bool> isAvailable();

  /// The product, or null when the store could not be asked.
  Future<PremiumProduct?> product();

  /// Does the store account own an active subscription? Null means the
  /// store could not be reached — the caller keeps what it had and never
  /// downgrades anyone on a failure (AC5).
  Future<bool?> isSubscribed();

  /// Opens the store's purchase flow. True once the purchase is owned.
  Future<bool> subscribe();

  /// Restores purchases for the signed-in store account (AC6).
  Future<bool> restore();

  /// The store's proof of purchase, for the managed AI proxy to check
  /// (PBI-027b). Null when nothing is owned or the store never answered.
  Future<String?> entitlementToken();
}

/// The real store.
class StoreBilling implements BillingSource {
  StoreBilling([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance {
    // The plugin asks to be listened to from launch, or purchases made
    // outside the app (or left pending) are missed.
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      AppLog.w('premium', 'purchase stream error: ${e.runtimeType}');
    });
  }

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Set once the store has reported an owned subscription in this run.
  bool _owned = false;

  /// The purchase token from that report. Never logged.
  String? _token;
  Completer<bool>? _pending;

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != premiumProductId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _owned = true;
          _token = p.verificationData.serverVerificationData;
        // Not a downgrade: a failed or abandoned attempt says nothing
        // about what the account already owns.
        case PurchaseStatus.error:
          AppLog.i('premium', 'purchase failed');
        case PurchaseStatus.canceled:
          AppLog.i('premium', 'purchase cancelled');
        case PurchaseStatus.pending:
          continue; // completePurchase on a pending purchase throws.
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } on Object catch (e) {
          AppLog.w('premium', 'completePurchase failed: ${e.runtimeType}');
        }
      }
    }
    if (purchases.any((p) => p.status != PurchaseStatus.pending)) {
      _settle(_owned);
    }
  }

  void _settle(bool value) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(value);
  }

  /// Waits for the store to answer, giving up rather than hanging.
  Future<bool> _await() {
    final completer = _pending = Completer<bool>();
    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        _pending = null;
        return _owned;
      },
    );
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } on Object catch (e) {
      AppLog.w('premium', 'store unavailable: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<PremiumProduct?> product() async {
    try {
      final response = await _iap.queryProductDetails({premiumProductId});
      final details = response.productDetails
          .where((d) => d.id == premiumProductId)
          .firstOrNull;
      if (details == null) return null;
      return PremiumProduct(
        id: details.id,
        price: details.price,
        title: details.title,
      );
    } on Object catch (e) {
      AppLog.w('premium', 'product lookup failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<bool?> isSubscribed() async {
    if (!await isAvailable()) return null;
    try {
      // The store replays what the account owns onto the stream.
      _owned = false;
      final answer = _await();
      await _iap.restorePurchases();
      return await answer;
    } on Object catch (e) {
      AppLog.w('premium', 'ownership check failed: ${e.runtimeType}');
      return null; // keep whatever was cached (AC5)
    }
  }

  @override
  Future<bool> subscribe() async {
    final details = await _iap.queryProductDetails({premiumProductId});
    final product = details.productDetails
        .where((d) => d.id == premiumProductId)
        .firstOrNull;
    if (product == null) return false;
    final answer = _await();
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      _settle(_owned);
      return false;
    }
    return answer;
  }

  @override
  Future<bool> restore() async => await isSubscribed() ?? false;

  @override
  Future<String?> entitlementToken() async => _token;
}

/// Build with `--dart-define=LIFEOS_TEST_PREMIUM=true` to swap the real
/// store for [TestPremiumBilling] on a test phone. Off by default, so a
/// normal build always uses the real store.
const testPremiumBuild = bool.fromEnvironment('LIFEOS_TEST_PREMIUM');

/// A stand-in store for test phones, before the Play product exists:
/// the subscription is always on sale and every purchase succeeds, with
/// no charge and no billing channel touched. It carries no purchase
/// token, so managed AI (PBI-027b) stays unavailable — the proxy would
/// reject it anyway.
class TestPremiumBilling implements BillingSource {
  const TestPremiumBilling();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<PremiumProduct?> product() async =>
      const PremiumProduct(id: premiumProductId, price: 'Test build');

  @override
  Future<bool?> isSubscribed() async => true;

  @override
  Future<bool> subscribe() async => true;

  @override
  Future<bool> restore() async => true;

  @override
  Future<String?> entitlementToken() async => null;
}

/// No store: the default everywhere until `main()` wires the real one,
/// and in tests. Nothing here reaches a billing channel.
class NoBilling implements BillingSource {
  const NoBilling();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<PremiumProduct?> product() async => null;

  @override
  Future<bool?> isSubscribed() async => null;

  @override
  Future<bool> subscribe() async => false;

  @override
  Future<bool> restore() async => false;

  @override
  Future<String?> entitlementToken() async => null;
}
