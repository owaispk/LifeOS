import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../atc_providers.dart';
import '../data/atc_learning.dart';
import '../data/atc_service.dart';
import 'rule_form.dart' show showUpgradePrompt;

/// M1 — ATC proposal dialog (UI flow M1). True = "Yes, remind me".
Future<bool?> showProposalDialog(BuildContext context, String question) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      key: const ValueKey('atc-proposal'),
      icon: const Text('⚡', style: TextStyle(fontSize: 32)),
      title: const Text('New pattern detected'),
      content: Text(question, key: const ValueKey('atc-proposal-text')),
      actions: [
        TextButton(
          key: const ValueKey('atc-proposal-no'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No thanks'),
        ),
        FilledButton(
          key: const ValueKey('atc-proposal-yes'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes, remind me'),
        ),
      ],
    ),
  );
}

/// "Fee increased from 12,000 → 13,500. Update future tasks?" (PBI-015).
Future<bool> showFeeChangeDialog(BuildContext context, FeeChange change) async {
  final yes = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      key: const ValueKey('fee-change'),
      title: Text(change.isIncrease ? 'Fee increased' : 'Fee changed'),
      content: Text(change.message),
      actions: [
        TextButton(
          key: const ValueKey('fee-change-keep'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep as is'),
        ),
        FilledButton(
          key: const ValueKey('fee-change-update'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Update future tasks'),
        ),
      ],
    ),
  );
  return yes ?? false;
}

/// Shows queued ATC proposals, at most one per day, on whichever tab the
/// user is on (PBI-014 grooming). Wraps the app shell's body.
class ProposalListener extends ConsumerStatefulWidget {
  const ProposalListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProposalListener> createState() => _ProposalListenerState();
}

class _ProposalListenerState extends ConsumerState<ProposalListener> {
  bool _busy = false;

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final service = ref.read(atcServiceProvider);
      final rule = await service.takeProposalForToday();
      if (rule == null || !mounted) return;
      final question = await service.proposalText(rule);
      if (!mounted) return;
      final yes = await showProposalDialog(context, question);
      if (yes == null) return; // closed: asked again another day
      await _answer(service, rule, yes);
    } finally {
      _busy = false;
    }
  }

  Future<void> _answer(AtcService service, AtcRule rule, bool yes) async {
    if (!yes) {
      await service.dismissProposal(rule.id);
      return;
    }
    try {
      await service.acceptProposal(rule.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('⚡ Auto-reminder is on')));
    } on FreeTierLimitException {
      if (mounted) await showUpgradePrompt(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(atcRulesProvider, (_, next) {
      final rules = next.value ?? const <AtcRule>[];
      if (rules.any((r) => r.status == 'proposed')) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _check());
      }
    });
    return widget.child;
  }
}
