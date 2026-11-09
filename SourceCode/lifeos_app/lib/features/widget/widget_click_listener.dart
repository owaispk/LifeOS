import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../core/router/deep_links.dart';
import 'widget_providers.dart';

/// Widget taps deep-link into the app (PBI-033 AC4): the score ring, a
/// task row or the payment line — on a cold start or while running. App
/// Lock stays in front (LockGate wraps the whole router); the target
/// shows after unlock.
class WidgetClickListener extends ConsumerStatefulWidget {
  const WidgetClickListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WidgetClickListener> createState() =>
      _WidgetClickListenerState();
}

class _WidgetClickListenerState extends ConsumerState<WidgetClickListener> {
  StreamSubscription<Uri?>? _sub;

  @override
  void initState() {
    super.initState();
    final gateway = ref.read(widgetGatewayProvider);
    _sub = gateway.clicks.listen(_open);
    gateway.initialUri().then(_open);
  }

  void _open(Uri? uri) {
    if (!mounted) return;
    final location = deepLinkLocation(uri);
    if (location == null) return;
    ref.read(routerProvider).go(location);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
