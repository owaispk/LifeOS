import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import 'data/atc_service.dart';

/// Premium entitlement — always false until subscriptions (PBI-029).
final premiumProvider = Provider<bool>((ref) => false);

final atcServiceProvider = Provider<AtcService>(
  (ref) => AtcService(
    ref.watch(repositoriesProvider),
    now: ref.watch(nowProvider),
    isPremium: ref.watch(premiumProvider),
  ),
);

/// Every live rule (active, paused, proposed, ended).
final atcRulesProvider = StreamProvider<List<AtcRule>>(
  (ref) => ref.watch(repositoriesProvider).atcRules.watchAll(),
);

/// Every live payment (forecast, rule history).
final allPaymentsProvider = StreamProvider<List<Payment>>(
  (ref) => ref.watch(repositoriesProvider).payments.watchAll(),
);
