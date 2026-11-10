import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_providers.dart';
import '../premium_providers.dart';

/// Re-checks a **paying** user's subscription when the app comes back,
/// at most once an hour, so a lapsed subscription eventually drops to
/// free (PBI-029 AC9).
///
/// A user who has never subscribed is never checked — nothing reaches
/// the billing SDK unless they open the Premium screen (AC10). That is
/// the whole reason this watches `premium_until` rather than just
/// refreshing on every resume.
class PremiumRefresher extends ConsumerStatefulWidget {
  const PremiumRefresher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PremiumRefresher> createState() => _PremiumRefresherState();
}

class _PremiumRefresherState extends ConsumerState<PremiumRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Never subscribed → never ask the store.
    if (ref.read(settingsProvider).value?.premiumUntil == null) return;
    unawaited(ref.read(premiumServiceProvider).refresh());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
