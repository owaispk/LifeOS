import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import 'atc_providers.dart';
import 'data/atc_service.dart';
import 'domain/atc_schedule.dart';
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
        body: const EmptyState(
          emoji: '⚡',
          title: 'This rule is gone',
          message: 'It was deleted. Tasks it created are still in Tasks.',
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

    return ListView(
      padding: const EdgeInsets.all(Tokens.spaceM),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cadenceLabel(rule), style: theme.textTheme.titleMedium),
                const SizedBox(height: Tokens.spaceXs),
                Text(
                  'Created ${history.created} '
                  '${history.created == 1 ? 'task' : 'tasks'} · '
                  '${history.paidOnTime} paid on time'
                  '${history.created > 0 && history.paidOnTime == history.created ? ' ✓' : ''}',
                  key: const ValueKey('rule-history'),
                ),
                if (rule.installmentTotal != null)
                  Text(
                    '${rule.installmentDone ?? 0} of '
                    '${rule.installmentTotal} paid',
                    key: const ValueKey('rule-installments'),
                  ),
              ],
            ),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('rule-active'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Create tasks automatically'),
          subtitle: Text(switch (rule.status) {
            'active' => 'On',
            'paused' => 'Paused — no new tasks',
            'ended' => 'Ended',
            _ => 'Waiting for your OK',
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
        const SizedBox(height: Tokens.spaceS),
        TextField(
          key: const ValueKey('detail-rule-name'),
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Tokens.spaceS),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('detail-rule-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: Tokens.spaceS),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                initialValue: _dueDay,
                decoration: const InputDecoration(
                  labelText: 'Due day',
                  border: OutlineInputBorder(),
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
        const SizedBox(height: Tokens.spaceS),
        SkipMonthsPicker(
          selected: _skip,
          onToggle: (m) => setState(
            () => _skip.contains(m) ? _skip.remove(m) : _skip.add(m),
          ),
        ),
        Row(
          children: [
            const Expanded(child: Text('Remind me before')),
            IconButton(
              tooltip: 'Fewer days',
              onPressed: _remind > 0 ? () => setState(() => _remind--) : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$_remind days'),
            IconButton(
              tooltip: 'More days',
              onPressed: _remind < 15 ? () => setState(() => _remind++) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: Tokens.spaceS),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved — applies to new tasks')),
              );
            }
          },
          child: const Text('Save changes'),
        ),
        const SizedBox(height: Tokens.spaceL),
        TextButton.icon(
          key: const ValueKey('detail-rule-delete'),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete rule'),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Delete "${rule.name}"?'),
                content: const Text(
                  'No new tasks will be created. Tasks it already made stay '
                  'in your list.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const ValueKey('confirm-rule-delete'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
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
