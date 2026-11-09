import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/now_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/data_providers.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../atc_providers.dart';
import '../data/atc_service.dart';
import '../domain/atc_schedule.dart' show freeTierRuleLimit;

/// "What do you pay regularly?" presets (PBI-013 grooming).
class PaymentPreset {
  const PaymentPreset(
    this.key,
    this.emoji,
    this.categoryKey, {
    this.amountOptional = false,
    this.installment = false,
  });
  final String key;
  final String emoji;
  final String categoryKey;

  /// Display label (also the suggested rule name), in the app's language.
  String get label {
    final l = l10nNow;
    return switch (key) {
      'rent' => l.atcPresetRent,
      'fees' => l.atcPresetFees,
      'utility' => l.atcPresetUtility,
      'internet' => l.atcPresetInternet,
      'mobile' => l.atcPresetMobile,
      'installment' => l.atcPresetInstallment,
      'subscription' => l.atcPresetSubscription,
      _ => l.atcPresetCustom,
    };
  }

  final bool amountOptional;
  final bool installment;
}

const paymentPresets = [
  PaymentPreset('rent', '🏠', 'rent'),
  PaymentPreset('fees', '🎓', 'fees'),
  PaymentPreset('utility', '💡', 'utilities', amountOptional: true),
  PaymentPreset('internet', '🌐', 'internet'),
  PaymentPreset('mobile', '📱', 'mobile'),
  PaymentPreset('installment', '📆', 'installment', installment: true),
  PaymentPreset('subscription', '🔁', 'subscription'),
  PaymentPreset('custom', '✳️', 'other', amountOptional: true),
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
      title: Text(context.l10n.atcUpgradeTitle),
      content: Text(context.l10n.atcUpgradeBody('$freeTierRuleLimit')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.atcNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.atcSeePremium),
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
  final _dates = <DateTime>[]; // semester dates (PBI-015 AC4)
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
              scheduleDates: _cycle == 'semester' ? _dates : const [],
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

  Future<void> _pickDate() async {
    final now = ref.read(nowProvider)();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null || _dates.contains(d)) return;
    setState(
      () => _dates
        ..add(d)
        ..sort(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final p = _preset;
    final l = context.l10n;

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
            Text(l.atcWhatPay, style: theme.textTheme.titleLarge),
            SizedBox(height: Tokens.spaceM),
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
              SizedBox(height: Tokens.spaceM),
              TextField(
                key: const ValueKey('rule-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.name,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: Tokens.spaceS),
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
                            ? l.atcAmountOptional
                            : l.amount,
                        prefixText: l.atcRsPrefix,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: Tokens.spaceS),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('rule-day'),
                      initialValue: _dueDay,
                      decoration: InputDecoration(
                        labelText: l.atcDueDay,
                        border: const OutlineInputBorder(),
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
                SizedBox(height: Tokens.spaceS),
                TextField(
                  key: const ValueKey('rule-total'),
                  controller: _total,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.atcInstallmentsTotal,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              SizedBox(height: Tokens.spaceM),
              Text(l.atcHowOften, style: theme.textTheme.labelLarge),
              Wrap(
                spacing: Tokens.spaceS,
                children: [
                  for (final c in [
                    ('monthly', l.atcMonthly),
                    ('quarterly', l.atcQuarterly),
                    ('semester', l.atcEvery6Months),
                    ('yearly', l.atcYearly),
                    ('once', l.atcOnce),
                  ])
                    ChoiceChip(
                      label: Text(c.$2),
                      selected: _cycle == c.$1,
                      onSelected: (_) => setState(() => _cycle = c.$1),
                    ),
                ],
              ),
              if (_cycle == 'semester') ...[
                SizedBox(height: Tokens.spaceS),
                Text(l.atcDueDates, style: theme.textTheme.labelLarge),
                Wrap(
                  spacing: Tokens.spaceS,
                  children: [
                    for (final d in _dates)
                      InputChip(
                        label: Text(formatDay(d)),
                        onDeleted: () => setState(() => _dates.remove(d)),
                      ),
                    ActionChip(
                      key: const ValueKey('rule-add-date'),
                      avatar: const Icon(Icons.event, size: 18),
                      label: Text(l.atcPickDates),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ],
              SizedBox(height: Tokens.spaceS),
              SkipMonthsPicker(
                selected: _skip,
                onToggle: (m) => setState(
                  () => _skip.contains(m) ? _skip.remove(m) : _skip.add(m),
                ),
              ),
              SizedBox(height: Tokens.spaceS),
              Row(
                children: [
                  Expanded(child: Text(l.atcRemindBefore)),
                  IconButton(
                    tooltip: l.atcFewerDays,
                    onPressed: _remind > 0
                        ? () => setState(() => _remind--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    l.atcDays('$_remind'),
                    key: const ValueKey('rule-remind'),
                  ),
                  IconButton(
                    tooltip: l.atcMoreDays,
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
                  decoration: InputDecoration(
                    labelText: l.atcFor,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.atcHousehold)),
                    for (final x in persons)
                      DropdownMenuItem(
                        value: x.id,
                        child: Text([x.avatar ?? '👤', x.name].join(' ')),
                      ),
                  ],
                  onChanged: (v) => setState(() => _personId = v),
                ),
              SizedBox(height: Tokens.spaceM),
              FilledButton(
                key: const ValueKey('rule-save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
                ),
                onPressed: _valid && !_saving ? _save : null,
                child: Text(l.atcTurnOn),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.atcSkipMonths,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Wrap(
          spacing: 4,
          children: [
            for (var m = 1; m <= 12; m++)
              FilterChip(
                key: ValueKey('skip-$m'),
                label: Text(shortMonth(DateTime(2000, m))),
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
