import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import '../tasks/tasks_providers.dart' show allTasksProvider, nowProvider;
import 'atc_providers.dart';
import 'data/atc_service.dart';
import 'domain/atc_schedule.dart';
import 'domain/bill_patterns.dart';
import '../capture/capture_entry.dart';
import '../money/domain/money_rules.dart' show parseIsoDate;
import 'ui/rule_form.dart';

/// Rule detail (PBI-017): edit, history, pause/resume, delete.
class RuleDetailScreen extends ConsumerWidget {
  const RuleDetailScreen({super.key, required this.ruleId});
  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(atcRulesProvider).value;
    final rule = rules?.where((r) => r.id == ruleId).firstOrNull;
    if (rules != null && rule == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          emoji: '⚡',
          title: context.l10n.atcRuleGone,
          message: context.l10n.atcRuleGoneBody,
        ),
      );
    }
    if (rule == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(rule.name)),
      body: _RuleForm(key: ValueKey('${rule.id}-${rule.version}'), rule: rule),
    );
  }
}

/// The predicted bill still hasn't been scanned 3+ days after its arrival
/// window (PBI-014 missed month): the earliest unpaid payment's task is
/// still a prediction (no source document).
bool lateBill(
  AtcRule rule,
  List<Payment> payments,
  List<Task> tasks,
  DateTime today,
) {
  if (rule.kind != 'bill_pattern' || rule.status != 'active') return false;
  final window = windowOf(rule);
  if (window == null) return false;
  final unpaid =
      payments
          .where((p) => p.status != 'paid' && p.status != 'skipped')
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  for (final p in unpaid) {
    final task = tasks.where((t) => t.id == p.taskId).firstOrNull;
    if (task == null || task.status != 'open') continue;
    if (task.sourceDocumentId != null) return false; // real bill arrived
    return isBillLate(
      predictedArrival: parseIsoDate(p.dueDate),
      windowTo: window.to,
      today: today,
    );
  }
  return false;
}

class _RuleForm extends ConsumerStatefulWidget {
  const _RuleForm({super.key, required this.rule});
  final AtcRule rule;

  @override
  ConsumerState<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<_RuleForm> {
  late final _name = TextEditingController(text: widget.rule.name);
  late final _amount = TextEditingController(
    text: widget.rule.amountMinor == null
        ? ''
        : Money.format(widget.rule.amountMinor!).replaceFirst('Rs ', ''),
  );
  late int _dueDay = widget.rule.dueDay ?? 1;
  late int _remind = widget.rule.remindDaysBefore;
  late final _skip = {...skipMonthsOf(widget.rule)};

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rule = widget.rule;
    final service = ref.read(atcServiceProvider);
    final payments = (ref.watch(allPaymentsProvider).value ?? const <Payment>[])
        .where((p) => p.atcRuleId == rule.id)
        .toList();
    final history = ruleHistory(payments);
    final late = lateBill(
      rule,
      payments,
      ref.watch(allTasksProvider).value ?? const <Task>[],
      ref.watch(nowProvider)(),
    );

    final l = context.l10n;
    final historyText = l.atcHistory(history.created, '${history.paidOnTime}');
    final allPaidOnTime =
        history.created > 0 && history.paidOnTime == history.created;

    return ListView(
      padding: EdgeInsets.all(Tokens.spaceM),
      children: [
        if (late) ...[
          Card(
            key: const ValueKey('missed-bill'),
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: EdgeInsets.all(Tokens.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.atcMissedBill(billStatsOf(rule).label ?? l.atcUtility),
                  ),
                  SizedBox(height: Tokens.spaceS),
                  Wrap(
                    spacing: Tokens.spaceS,
                    children: [
                      FilledButton.tonal(
                        key: const ValueKey('missed-bill-scan'),
                        onPressed: () => startScan(context),
                        child: Text(l.atcIllScan),
                      ),
                      TextButton(
                        key: const ValueKey('missed-bill-pause'),
                        onPressed: () => service.pause(rule.id),
                        child: Text(l.atcPause),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Tokens.spaceS),
        ],
        Card(
          child: Padding(
            padding: EdgeInsets.all(Tokens.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cadenceLabel(rule), style: theme.textTheme.titleMedium),
                SizedBox(height: Tokens.spaceXs),
                Text(
                  allPaidOnTime ? '$historyText ✓' : historyText,
                  key: const ValueKey('rule-history'),
                ),
                if (rule.installmentTotal != null)
                  Text(
                    l.atcInstallments(
                      '${rule.installmentDone ?? 0}',
                      '${rule.installmentTotal}',
                    ),
                    key: const ValueKey('rule-installments'),
                  ),
              ],
            ),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('rule-active'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.atcCreateAuto),
          subtitle: Text(switch (rule.status) {
            'active' => l.atcStatusOn,
            'paused' => l.atcStatusPaused,
            'ended' => l.atcEnded,
            _ => l.atcWaitingOk,
          }),
          value: rule.status == 'active',
          onChanged: rule.status == 'ended'
              ? null
              : (on) async {
                  try {
                    on
                        ? await service.resume(rule.id)
                        : await service.pause(rule.id);
                  } on FreeTierLimitException {
                    if (context.mounted) await showUpgradePrompt(context);
                  }
                },
        ),
        SizedBox(height: Tokens.spaceS),
        TextField(
          key: const ValueKey('detail-rule-name'),
          controller: _name,
          decoration: InputDecoration(
            labelText: l.name,
            border: const OutlineInputBorder(),
          ),
        ),
        SizedBox(height: Tokens.spaceS),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('detail-rule-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.amount,
                  prefixText: l.atcRsPrefix,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: Tokens.spaceS),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                initialValue: _dueDay,
                decoration: InputDecoration(
                  labelText: l.atcDueDay,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (d) => setState(() => _dueDay = d ?? _dueDay),
              ),
            ),
          ],
        ),
        SizedBox(height: Tokens.spaceS),
        SkipMonthsPicker(
          selected: _skip,
          onToggle: (m) => setState(
            () => _skip.contains(m) ? _skip.remove(m) : _skip.add(m),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(l.atcRemindBefore)),
            IconButton(
              tooltip: l.atcFewerDays,
              onPressed: _remind > 0 ? () => setState(() => _remind--) : null,
              icon: const Icon(Icons.remove),
            ),
            Text(l.atcDays('$_remind')),
            IconButton(
              tooltip: l.atcMoreDays,
              onPressed: _remind < 15 ? () => setState(() => _remind++) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        SizedBox(height: Tokens.spaceS),
        FilledButton(
          key: const ValueKey('detail-rule-save'),
          onPressed: () async {
            await service.edit(
              rule.id,
              name: _name.text.isEmpty ? rule.name : _name.text,
              amountMinor: Money.parseMinor(_amount.text),
              dueDay: _dueDay,
              remindDaysBefore: _remind,
              skipMonths: _skip.toList(),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.atcSavedNewTasks)));
            }
          },
          child: Text(l.atcSaveChanges),
        ),
        SizedBox(height: Tokens.spaceL),
        TextButton.icon(
          key: const ValueKey('detail-rule-delete'),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: Text(l.atcDeleteRule),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.l10n.atcDeleteTitle(rule.name)),
                content: Text(context.l10n.atcDeleteBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.cancel),
                  ),
                  FilledButton(
                    key: const ValueKey('confirm-rule-delete'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.l10n.atcDelete),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            await service.delete(rule.id);
            if (context.mounted) context.go('/more/atc');
          },
        ),
      ],
    );
  }
}
