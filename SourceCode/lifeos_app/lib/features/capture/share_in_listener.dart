import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import 'capture_entry.dart';
import 'capture_providers.dart';
import 'platform/capture_platform.dart';

/// "Share to LifeOS" (PBI-003 AC8): files shared from another app — at
/// launch or while running — open the confirm step with source `share_in`.
class ShareInListener extends ConsumerStatefulWidget {
  const ShareInListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShareInListener> createState() => _ShareInListenerState();
}

class _ShareInListenerState extends ConsumerState<ShareInListener> {
  StreamSubscription<List<IncomingFile>>? _sub;

  @override
  void initState() {
    super.initState();
    final inbox = ref.read(shareInboxProvider);
    _sub = inbox.incoming.listen(_receive);
    inbox.initial().then(_receive);
  }

  void _receive(List<IncomingFile> files) {
    if (!mounted || files.isEmpty) return;
    addIncoming(
      ProviderScope.containerOf(context, listen: false),
      files,
      source: 'share_in',
    );
    ref.read(shareInboxProvider).reset();
    final router = ref.read(routerProvider);
    if (router.state.matchedLocation != captureRoute) {
      router.push(captureRoute);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
