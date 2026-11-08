import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/data_providers.dart';
import '../../../data/db/app_database.dart';
import '../atc_providers.dart';
import '../data/atc_service.dart';

/// "What do you pay regularly?" presets (PBI-013 grooming).
class PaymentPreset {
  const PaymentPreset(
    this.key,
    this.emoji,
    this.label,
    this.categoryKey, {
    this.amountOptional = false,
    this.installment = false,
  });
  final String key;
  final String emoji;
  final String label;
  final String categoryKey;
  final bool amountOptional;
  final bool installment;
}

const paymentPresets = [
  PaymentPreset('rent', '🏠', 'Rent', 'rent'),
  PaymentPreset('fees', '🎓', 'School fee', 'fees'),
  PaymentPreset(
    'utility',
    '💡',
    'Utility bill',
    'utilities',
    amountOptional: true,
  ),
  PaymentPreset('internet', '🌐', 'Internet', 'internet'),
  PaymentPreset('mobile', '📱', 'Mobile', 'mobile'),
  PaymentPreset(
    'installment',
    '📆',
    'Installment / Committee',
    'installment',
    installment: true,
  ),
  PaymentPreset('subscription', '🔁', 'Subscription', 'subscription'),
  PaymentPreset('custom', '✳️', 'Custom', 'other', amountOptional: true),
];

/// Opens the add-rule sheet. Shows the upgrade prompt on the 4th rule.
Future<void> showAddRuleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    isScrollControlled: true,
    builder: (context) => const AddRuleSheet(),
  );
}

Future<void> showUpgradePrompt(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('upgrade-prompt'),
      title: const Text('Upgrade to Premium'),
      content: const Text(
        'Free plan includes 3 auto-rules — Premium removes the limit.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('See Premium'),
        ),
      ],
    ),
  );
}

class AddRuleSheet extends ConsumerStatefulWidget {
  const AddRuleSheet({super.key});

  @override
  ConsumerState<AddRuleSheet> createState() => _AddRuleSheetState();
}

class _AddRuleSheetState extends ConsumerState<AddRuleSheet> {
  PaymentPreset? _preset;
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _total = TextEditingController(text: '12');
  int _dueDay = 1;
  String _cycle = 'monthly';
  int _remind = 5;
  final _skip = <int>{};
  String? _personId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _total.dispose();
    super.dispose();
  }

  int? get _amountMinor => Money.parseMinor(_amount.text);

  bool get _valid {
    final p = _preset;
    if (p == null || _name.text.trim().isEmpty) return false;
    if (!p.amountOptional && (_amountMinor == null || _amountMinor! <= 0)) {
      return false;
    }
    if (p.installment && (int.tryParse(_total.text) ?? 0) < 1) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final p = _preset!;
    try {
      await ref
          .read(atcServiceProvider)
          .createRule(
            RuleInput(
              name: _name.text,
              categoryKey: p.categoryKey,
              dueDay: _dueDay,
              amountMinor: _amountMinor,
              cycle: _cycle,
              skipMonths: _skip.toList(),
              installmentTotal: p.installment ? int.parse(_total.text) : null,
              remindDaysBefore: _remind,
              personId: _personId,
            ),
          );
      if (mounted) Navigator.pop(context);
    } on FreeTierLimitException {
      if (!mounted) return;
      Navigator.pop(context);
      await showUpgradePrompt(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final p = _preset;

    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.spaceM,
        right: Tokens.spaceM,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.spaceM,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What do you pay regularly?',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Tokens.spaceM),
            Wrap(
              spacing: Tokens.spaceS,
              runSpacing: Tokens.spaceXs,
              children: [
                for (final preset in paymentPresets)
                  ChoiceChip(
                    key: ValueKey('preset-${preset.key}'),
                    label: Text('${preset.emoji} ${preset.label}'),
                    selected: p == preset,
                    onSelected: (_) => setState(() {
                      _preset = preset;
                      if (_name.text.isEmpty ||
                          paymentPresets.any((x) => x.label == _name.text)) {
                        _name.text = preset.label;
                      }
                    }),
                  ),
              ],
            ),
            if (p != null) ...[
              const SizedBox(height: Tokens.spaceM),
              TextField(
                key: const ValueKey('rule-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Tokens.spaceS),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('rule-amount'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: p.amountOptional
                            ? 'Amount (optional)'
                            : 'Amount',
                        prefixText: 'Rs ',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Tokens.spaceS),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('rule-day'),
                      initialValue: _dueDay,
                      decoration: const InputDecoration(
                        labelText: 'Due day',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var d = 1; d <= 31; d++)
                          DropdownMenuItem(value: d, child: Text('$d')),
                      ],
                      onChanged: (d) => setState(() => _dueDay = d ?? 1),
                    ),
                  ),
                ],
              ),
              if (p.installment) ...[
                const SizedBox(height: Tokens.spaceS),
                TextField(
                  key: const ValueKey('rule-total'),
                  controller: _total,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'How many installments in total',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: Tokens.spaceM),
              Text('How often', style: theme.textTheme.labelLarge),
              Wrap(
                spacing: Tokens.spaceS,
                children: [
                  for (final c in const [
                    ('monthly', 'Monthly'),
                    ('quarterly', 'Quarterly'),
                    ('semester', 'Every 6 months'),
                    ('yearly', 'Yearly'),
                    ('once', 'Once'),
                  ])
                    ChoiceChip(
                      label: Text(c.$2),
                      selected: _cycle == c.$1,
                      onSelected: (_) => setState(() => _cycle = c.$1),
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
              const SizedBox(height: Tokens.spaceS),
              Row(
                children: [
                  const Expanded(child: Text('Remind me before')),
                  IconButton(
                    tooltip: 'Fewer days',
                    onPressed: _remind > 0
                        ? () => setState(() => _remind--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$_remind days', key: const ValueKey('rule-remind')),
                  IconButton(
                    tooltip: 'More days',
                    onPressed: _remind < 15
                        ? () => setState(() => _remind++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (persons.length > 1)
                DropdownButtonFormField<String?>(
                  initialValue: _personId,
                  decoration: const InputDecoration(
                    labelText: 'For',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Household'),
                    ),
                    for (final x in persons)
                      DropdownMenuItem(
                        value: x.id,
                        child: Text('${x.avatar ?? '👤'} ${x.name}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _personId = v),
                ),
              const SizedBox(height: Tokens.spaceM),
              FilledButton(
                key: const ValueKey('rule-save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
                ),
                onPressed: _valid && !_saving ? _save : null,
                child: const Text('⚡ Turn on auto-reminder'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Month toggles for "skip these months" (e.g. school vacations).
class SkipMonthsPicker extends StatelessWidget {
  const SkipMonthsPicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skip these months',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Wrap(
          spacing: 4,
          children: [
            for (var m = 1; m <= 12; m++)
              FilterChip(
                key: ValueKey('skip-$m'),
                label: Text(_names[m - 1]),
                selected: selected.contains(m),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onToggle(m),
              ),
          ],
        ),
      ],
    );
  }
}
