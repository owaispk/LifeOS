import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../domain/limits.dart';

/// Which wall the user walked into (PBI-029).
enum UpgradeReason { rules, documents }

/// "You are on the free plan" — shown when a limit stops something, and
/// only then. **Not now** leaves everything exactly as it was; **See
/// Premium** opens the Premium screen.
Future<void> showUpgradePrompt(
  BuildContext context, {
  UpgradeReason reason = UpgradeReason.rules,
}) {
  final l = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('upgrade-prompt'),
      title: Text(l.atcUpgradeTitle),
      content: Text(
        switch (reason) {
          UpgradeReason.rules => l.atcUpgradeBody('$freeTierRuleLimit'),
          UpgradeReason.documents => l.pmDocLimitBody(
            '$freeTierDocumentLimit',
          ),
        },
      ),
      actions: [
        TextButton(
          key: const ValueKey('upgrade-not-now'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.atcNotNow),
        ),
        FilledButton(
          key: const ValueKey('upgrade-see-premium'),
          onPressed: () {
            Navigator.pop(context);
            context.go(premiumRoute);
          },
          child: Text(l.atcSeePremium),
        ),
      ],
    ),
  );
}

/// Where the Premium screen lives.
const premiumRoute = '/more/premium';
