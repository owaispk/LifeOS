import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/limits.dart';
import '../premium_providers.dart';

/// 5.7 Premium (PBI-029). Sells what Premium does **today** — unlimited
/// documents and unlimited auto-rules — and nothing else. Cloud backup,
/// share links and AI are not built, so they are not advertised here.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<bool> Function() action, String failed) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? null : failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final premium = ref.watch(premiumProvider);
    final product = ref.watch(premiumProductProvider).value;
    final service = ref.read(premiumServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsPremium)),
      body: ListView(
        key: const ValueKey('premium-list'),
        padding: EdgeInsets.all(Tokens.spaceL),
        children: [
          Text(
            premium ? l.pmYourePremium : l.pmHeadline,
            key: const ValueKey('premium-state'),
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: Tokens.spaceM),
          // Only what Premium actually does today (AC7).
          _Perk(l.pmPerkDocuments('$freeTierDocumentLimit')),
          _Perk(l.pmPerkRules('$freeTierRuleLimit')),
          SizedBox(height: Tokens.spaceL),
          if (premium) ...[
            Text(l.pmManageInStore, key: const ValueKey('premium-manage')),
          ] else ...[
            // The store's own price, in its own currency (AC7).
            if (product != null)
              Text(
                l.pmPricePerMonth(product.price),
                key: const ValueKey('premium-price'),
                style: theme.textTheme.titleMedium,
              )
            else
              Text(
                l.pmPriceUnavailable,
                key: const ValueKey('premium-price-unavailable'),
                style: theme.textTheme.bodySmall,
              ),
            SizedBox(height: Tokens.spaceM),
            FilledButton(
              key: const ValueKey('premium-subscribe'),
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(Tokens.minTouchTarget),
              ),
              onPressed: _busy || product == null
                  ? null
                  : () => _run(service.subscribe, l.pmPurchaseFailed),
              child: Text(l.pmSubscribe),
            ),
          ],
          SizedBox(height: Tokens.spaceS),
          // Its own button, never buried: a new phone is one tap from
          // what the user already pays for (AC6).
          OutlinedButton(
            key: const ValueKey('premium-restore'),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(Tokens.minTouchTarget),
            ),
            onPressed: _busy
                ? null
                : () => _run(service.restore, l.pmNothingToRestore),
            child: Text(l.pmRestore),
          ),
          if (_message != null) ...[
            SizedBox(height: Tokens.spaceM),
            Text(
              _message!,
              key: const ValueKey('premium-message'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          SizedBox(height: Tokens.spaceL),
          Text(
            l.pmNoAccountNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: Tokens.spaceS),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⭐'),
        SizedBox(width: Tokens.spaceS),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
