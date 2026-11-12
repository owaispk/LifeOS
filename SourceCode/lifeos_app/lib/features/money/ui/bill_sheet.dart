import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/now_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../domain/money_rules.dart';
import '../money_providers.dart';
import 'category_colors.dart';
import 'paid_sheet.dart' show paymentServiceProvider;

/// Reminder lead times offered for a one-off bill, in days.
const billReminderChoices = [0, 1, 3, 7];

/// "Bill to pay" (PBI-038 F-05): a one-off payment due on a date — a bill
/// that hasn't been paid yet, unlike an expense. It lands in the Forecast
/// and the month's "still to pay", with a reminder, and is paid through
/// the usual completion chain.
Future<void> showBillSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    isScrollControlled: true,
    builder: (context) => const BillSheet(),
  );
}

class BillSheet extends ConsumerStatefulWidget {
  const BillSheet({super.key});

  @override
  ConsumerState<BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends ConsumerState<BillSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String? _categoryId;
  DateTime? _due;
  int _remindDays = 1;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Null when empty (the amount is optional) or invalid.
  int? get _amountMinor {
    final v = Money.parseMinor(_amount.text);
    return (v == null || v <= 0) ? null : v;
  }

  bool get _amountInvalid => _amount.text.isNotEmpty && _amountMinor == null;

  bool get _canSave =>
      !_saving &&
      _name.text.trim().isNotEmpty &&
      _due != null &&
      !_amountInvalid;

  Future<void> _save() async {
    setState(() => _saving = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(paymentServiceProvider)
        .addBill(
          title: _name.text,
          due: _due!,
          amountMinor: _amountMinor,
          categoryId: _categoryId,
          remindDaysBefore: _remindDays,
        );
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('bill-added-snackbar'),
        content: Text(l.mnBillAdded(dayMonth(_due!))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final categories = ref.watch(categoriesProvider).value ?? const [];
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
            Text(l.mnAddBill, style: theme.textTheme.titleLarge),
            SizedBox(height: Tokens.spaceXs),
            Text(
              l.mnAddBillSub,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: Tokens.spaceM),
            TextField(
              key: const ValueKey('bill-name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.name,
                hintText: l.mnBillNameHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: Tokens.spaceS),
            TextField(
              key: const ValueKey('bill-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.atcAmountOptional,
                prefixText: Money.prefix,
                border: const OutlineInputBorder(),
                errorText: _amountInvalid ? l.mnAmountError : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            ListTile(
              key: const ValueKey('bill-due'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l.mnDueDate),
              subtitle: Text(
                _due == null ? l.mnPickDueDate : relativeDay(_due!, now),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _due ?? today,
                  firstDate: today,
                  lastDate: DateTime(today.year + 1, today.month, today.day),
                );
                if (picked != null) setState(() => _due = picked);
              },
            ),
            Row(
              children: [
                Expanded(child: Text(l.atcRemindBefore)),
                DropdownButton<int>(
                  key: const ValueKey('bill-remind'),
                  value: _remindDays,
                  items: [
                    for (final d in billReminderChoices)
                      DropdownMenuItem(
                        value: d,
                        child: Text(
                          d == 0 ? l.mnRemindOnDay : l.mnRemindDaysBefore(d),
                        ),
                      ),
                  ],
                  onChanged: (d) => setState(() => _remindDays = d ?? 1),
                ),
              ],
            ),
            SizedBox(height: Tokens.spaceS),
            Text(l.mnCategory, style: theme.textTheme.labelLarge),
            SizedBox(height: Tokens.spaceS),
            Wrap(
              spacing: Tokens.spaceS,
              runSpacing: Tokens.spaceXs,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    key: ValueKey('bill-category-${c.systemKey ?? c.id}'),
                    avatar: CircleAvatar(
                      radius: 5,
                      backgroundColor: categoryColor(context, colorSlotFor(c)),
                    ),
                    label: Text('${c.icon ?? ''} ${categoryName(c)}'.trim()),
                    selected: _categoryId == c.id,
                    onSelected: (on) =>
                        setState(() => _categoryId = on ? c.id : null),
                  ),
              ],
            ),
            SizedBox(height: Tokens.spaceM),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                key: const ValueKey('bill-save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, Tokens.minTouchTarget),
                ),
                onPressed: _canSave ? _save : null,
                child: Text(l.mnAdd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
