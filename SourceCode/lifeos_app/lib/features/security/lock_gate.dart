import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/l10n.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../settings/settings_providers.dart';

/// Biometric / device-PIN check (PBI-024). Faked in tests.
abstract interface class Authenticator {
  /// The phone has a fingerprint, face or screen lock set up.
  Future<bool> canAuthenticate();

  /// Asks the user; true when they passed.
  Future<bool> authenticate(String reason);
}

class LocalAuthenticator implements Authenticator {
  LocalAuthenticator();
  final _auth = LocalAuthentication();

  @override
  Future<bool> canAuthenticate() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } on Object {
      return false;
    }
  }
}

/// No authentication available (tests by default, the web preview): locks
/// never engage, so nothing can lock the user out.
class NoAuthenticator implements Authenticator {
  const NoAuthenticator();

  @override
  Future<bool> canAuthenticate() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

final authenticatorProvider = Provider<Authenticator>(
  (ref) => const NoAuthenticator(),
);

/// Whether the device can authenticate (drives the Security toggles).
final canAuthenticateProvider = FutureProvider<bool>(
  (ref) => ref.watch(authenticatorProvider).canAuthenticate(),
);

/// Lock state for this run of the app.
class LockState {
  const LockState({this.appLocked = false, this.vaultUnlocked = false});
  final bool appLocked;

  /// Vault lock passed since the app last went to the background.
  final bool vaultUnlocked;

  LockState copyWith({bool? appLocked, bool? vaultUnlocked}) => LockState(
    appLocked: appLocked ?? this.appLocked,
    vaultUnlocked: vaultUnlocked ?? this.vaultUnlocked,
  );
}

class LockController extends Notifier<LockState> {
  @override
  LockState build() => const LockState();

  void lockApp() => state = state.copyWith(appLocked: true);
  void unlockApp() => state = state.copyWith(appLocked: false);
  void unlockVault() => state = state.copyWith(vaultUnlocked: true);
  void relockVault() => state = state.copyWith(vaultUnlocked: false);
}

final lockProvider = NotifierProvider<LockController, LockState>(
  LockController.new,
);

/// Screenshot blocking (PBI-024 AC5): FLAG_SECURE on Android.
const secureChannel = MethodChannel('lifeos/secure');

Future<void> setScreenSecure(bool on) async {
  try {
    await secureChannel.invokeMethod<void>('setSecure', on);
  } on Object {
    // Not Android (or no channel in tests): nothing to block.
  }
}

/// Covers the whole app with the lock screen when App lock is on: on cold
/// start and after `auto_lock_min` minutes in the background (AC3).
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _coldChecked = false;
  DateTime? _backgroundAt;
  bool _asking = false;

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

  Future<bool> _enabled() async {
    final s = ref.read(settingsProvider).value;
    if (s == null || !s.appLock) return false;
    return ref.read(authenticatorProvider).canAuthenticate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = ref.read(nowProvider)();
    if (state == AppLifecycleState.paused) {
      _backgroundAt = now;
      ref.read(lockProvider.notifier).relockVault();
    } else if (state == AppLifecycleState.resumed && _backgroundAt != null) {
      final away = now.difference(_backgroundAt!);
      _backgroundAt = null;
      final minutes = ref.read(settingsProvider).value?.autoLockMin ?? 5;
      if (away >= Duration(minutes: minutes)) _lockIfEnabled();
    }
  }

  Future<void> _lockIfEnabled() async {
    if (await _enabled() && mounted) {
      ref.read(lockProvider.notifier).lockApp();
      await _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    try {
      final ok = await ref
          .read(authenticatorProvider)
          .authenticate(context.l10n.unlockReason);
      if (ok && mounted) ref.read(lockProvider.notifier).unlockApp();
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cold start: lock once the settings have loaded.
    ref.listen(settingsProvider, (_, next) {
      if (_coldChecked || next.value == null) return;
      _coldChecked = true;
      if (next.value!.appLock) _lockIfEnabled();
    });
    final locked = ref.watch(lockProvider.select((s) => s.appLocked));
    return Stack(
      children: [
        widget.child,
        if (locked)
          Positioned.fill(
            child: _LockScreen(
              key: const ValueKey('app-lock'),
              title: context.l10n.lockedTitle,
              onUnlock: _unlock,
            ),
          ),
      ],
    );
  }
}

/// Asks again before showing the Vault when Vault lock is on (AC4), and
/// blocks screenshots while it is visible if that setting is on (AC5).
class VaultGate extends ConsumerStatefulWidget {
  const VaultGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends ConsumerState<VaultGate> {
  bool _secure = false;

  @override
  void dispose() {
    if (_secure) setScreenSecure(false);
    super.dispose();
  }

  Future<void> _unlock() async {
    final ok = await ref
        .read(authenticatorProvider)
        .authenticate(context.l10n.unlockVaultReason);
    if (ok && mounted) ref.read(lockProvider.notifier).unlockVault();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).value;
    final canAuth = ref.watch(canAuthenticateProvider).value ?? false;
    final unlocked = ref.watch(lockProvider.select((l) => l.vaultUnlocked));

    // Offstage tabs keep their widgets: only block while really visible.
    final visible = TickerMode.valuesOf(context).enabled;
    final wantSecure = visible && (s?.screenshotBlock ?? false);
    if (wantSecure != _secure) {
      _secure = wantSecure;
      setScreenSecure(wantSecure);
    }

    if ((s?.vaultLock ?? false) && canAuth && !unlocked) {
      return _LockScreen(
        key: const ValueKey('vault-lock'),
        title: context.l10n.vaultLockedTitle,
        onUnlock: _unlock,
        autoAsk: visible,
      );
    }
    return widget.child;
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen({
    super.key,
    required this.title,
    required this.onUnlock,
    this.autoAsk = true,
  });

  final String title;
  final Future<void> Function() onUnlock;
  final bool autoAsk;

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoAsk) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onUnlock());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: Tokens.spaceM),
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: Tokens.spaceL),
              FilledButton.icon(
                key: const ValueKey('unlock'),
                onPressed: widget.onUnlock,
                icon: const Icon(Icons.fingerprint),
                label: Text(context.l10n.unlock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
