import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ids.dart';
import '../../core/l10n.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../../shared/widgets/empty_state.dart';
import '../money/domain/money_rules.dart' show parseIsoDate;
import '../money/money_providers.dart' show categoriesProvider;
import '../tasks/tasks_providers.dart' show allTasksProvider;
import 'atc_providers.dart';
import 'data/atc_service.dart';
import 'domain/atc_schedule.dart';
import 'ui/rule_form.dart';

/// Rule groups (PBI-017 grooming).
enum RuleGroup { bills, fees, fixed, appointments }

RuleGroup groupOf(AtcRule r, Map<String, Category> categories) {
  final key = categories[r.categoryId]?.systemKey;
  if (r.kind == 'appointment_followup') return RuleGroup.appointments;
  if (r.kind == 'bill_pattern' || key == 'utilities') return RuleGroup.bills;
  if (r.kind == 'fee' || key == 'fees') return RuleGroup.fees;
  return RuleGroup.fixed;
}

/// Stable ids for widget keys (`atc-group-Bills`).
const _groupIds = {
  RuleGroup.bills: 'Bills',
  RuleGroup.fees: 'Fees',
  RuleGroup.fixed: 'Fixed',
  RuleGroup.appointments: 'Appointments',
};

String _groupTitle(AppLocalizations l, RuleGroup g) => switch (g) {
  RuleGroup.bills => l.atcGroupBills,
  RuleGroup.fees => l.atcGroupFees,
  RuleGroup.fixed => l.atcGroupFixed,
  RuleGroup.appointments => l.atcGroupAppointments,
};

/// 5.1 ATC Rules Manager (PBI-017).
class AtcRulesScreen extends ConsumerWidget {
  const AtcRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = (ref.watch(atcRulesProvider).value ?? const <AtcRule>[])
        .where((r) => r.status != 'dismissed')
        .toList();
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    final tasks = ref.watch(allTasksProvider).value ?? const <Task>[];
    final now = ref.watch(nowProvider)();
    final createdThisMonth = tasks.where((t) {
      if (t.atcRuleId == null) return false;
      final c = DateTime.fromMillisecondsSinceEpoch(
        IdGenerator.timestampOf(t.id),
      );
      return c.year == now.year && c.month == now.month;
    }).length;

    final l = context.l10n;
    final groups = <RuleGroup, List<AtcRule>>{};
    for (final r in rules) {
      groups.putIfAbsent(groupOf(r, categories), () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.atcTitle),
        actions: [
          // In the app bar, not a second floating button beside the ➕.
          Padding(
            padding: EdgeInsets.only(right: Tokens.spaceS),
            child: FilledButton.tonalIcon(
              key: const ValueKey('atc-add'),
              onPressed: () => showAddRuleSheet(context),
              icon: const Icon(Icons.add),
              label: Text(l.atcAdd),
            ),
          ),
        ],
      ),
      body: rules.isEmpty
          ? EmptyState(
              emoji: '⚡',
              title: l.atcEmptyTitle,
              message: l.atcEmptyBody,
              actionLabel: l.atcEmptyAction,
              onAction: () => showAddRuleSheet(context),
            )
          : ListView(
              key: const ValueKey('atc-list'),
              padding: EdgeInsets.only(bottom: Tokens.listEnd),
              children: [
                Padding(
                  padding: EdgeInsets.all(Tokens.spaceM),
                  child: Text(
                    l.atcCreatedThisMonth(createdThisMonth),
                    key: const ValueKey('atc-header'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final g in RuleGroup.values)
                  if (groups[g] != null) ...[
                    _GroupTitle(id: _groupIds[g]!, title: _groupTitle(l, g)),
                    for (final r in groups[g]!) _RuleTile(rule: r, now: now),
                  ],
              ],
            ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.id, required this.title});
  final String id;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Tokens.gutter,
        Tokens.spaceM,
        Tokens.gutter,
        Tokens.spaceXs,
      ),
      child: Text(
        title.toUpperCase(),
        key: ValueKey('atc-group-$id'),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule, required this.now});
  final AtcRule rule;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = rule.lastGeneratedPeriod == null
        ? null
        : parseIsoDate(rule.lastGeneratedPeriod!);
    final l = context.l10n;
    final status = switch (rule.status) {
      'proposed' => l.atcProposed,
      'ended' => l.atcEnded,
      'paused' => l.atcPaused,
      _ => next == null ? null : l.atcNext(relativeDay(next, now)),
    };
    final service = ref.read(atcServiceProvider);

    return ListTile(
      key: ValueKey('rule-${rule.id}'),
      title: Text(occurrenceTitle(rule)),
      subtitle: Text([cadenceLabel(rule), ?status].join(' · ')),
      onTap: () => context.go('/more/atc/${rule.id}'),
      trailing: rule.status == 'ended' || rule.status == 'proposed'
          ? null
          : Switch(
              key: ValueKey('rule-switch-${rule.id}'),
              value: rule.status == 'active',
              onChanged: (on) async {
                try {
                  if (on) {
                    await service.resume(rule.id);
                  } else {
                    await service.pause(rule.id);
                  }
                } on FreeTierLimitException {
                  if (context.mounted) await showUpgradePrompt(context);
                }
              },
            ),
    );
  }
}
