import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../security/lock_gate.dart';
import '../tasks/ui/new_task_sheet.dart';
import 'capture_entry.dart';
import 'capture_providers.dart';
import 'platform/capture_platform.dart';

/// "Share to LifeOS": files shared from another app open the confirm step
/// with source `share_in` (PBI-003 AC8); plain text opens the new-task
/// sheet, pre-filled and parsed (PBI-034).
class ShareInListener extends ConsumerStatefulWidget {
  const ShareInListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShareInListener> createState() => _ShareInListenerState();
}

class _ShareInListenerState extends ConsumerState<ShareInListener> {
  StreamSubscription<SharedIn>? _sub;

  /// Text that arrived while the app was locked (PBI-034 AC4). Held in
  /// memory only, never logged (PBI-030), and dropped once shown.
  String? _pendingText;

  @override
  void initState() {
    super.initState();
    final inbox = ref.read(shareInboxProvider);
    _sub = inbox.incoming.listen(_receive);
    inbox.initial().then(_receive);
  }

  void _receive(SharedIn shared) {
    if (!mounted || shared.isEmpty) return;
    ref.read(shareInboxProvider).reset();
    if (shared.files.isNotEmpty) {
      addIncoming(
        ProviderScope.containerOf(context, listen: false),
        shared.files,
        source: 'share_in',
      );
      final router = ref.read(routerProvider);
      if (router.state.matchedLocation != captureRoute) {
        router.push(captureRoute);
      }
      return;
    }
    _pendingText = shared.text;
    _showPendingText();
  }

  /// Opens the sheet once the app is unlocked: App Lock covers the whole
  /// app, and a sheet under it would show the shared text to whoever
  /// picked the phone up.
  void _showPendingText() {
    final text = _pendingText;
    if (text == null || !mounted) return;
    if (ref.read(lockProvider).appLocked) return;
    _pendingText = null;
    // Read the router now: this may be called from build (the unlock
    // listener below), and `ref` is unusable once we are off the tree.
    final router = ref.read(routerProvider);
    // Off this turn of the loop, so showing the sheet never lands inside a
    // build. Not a post-frame callback: that waits for a frame nothing has
    // asked for.
    Future.microtask(() {
      if (!mounted) return;
      // This widget wraps MaterialApp's builder and so sits above the
      // Navigator; the sheet goes to the router's navigator instead.
      final nav = router.routerDelegate.navigatorKey.currentContext;
      if (nav != null && nav.mounted) showNewTaskSheet(nav, initialText: text);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lockProvider.select((s) => s.appLocked), (_, locked) {
      if (!locked) _showPendingText();
    });
    return widget.child;
  }
}
