import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/now_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../data/expense_service.dart';
import '../domain/money_rules.dart';
import '../money_providers.dart';
import 'bill_sheet.dart';
import 'category_colors.dart';
import 'paid_sheet.dart' show confirmMarkUnpaid;

/// 4.4 Add Expense (bottom sheet) — also used to edit an existing expense.
Future<void> showExpenseSheet(BuildContext context, {Expense? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    isScrollControlled: true,
    builder: (context) => ExpenseSheet(existing: existing),
  );
}

class ExpenseSheet extends ConsumerStatefulWidget {
  const ExpenseSheet({super.key, this.existing});

  final Expense? existing;

  @override
  ConsumerState<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<ExpenseSheet> {
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.formatPlain(widget.existing!.amountMinor),
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String? _categoryId = widget.existing?.categoryId;
  late DateTime? _date = widget.existing == null
      ? null
      : parseIsoDate(widget.existing!.spentOn);
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _amountMinor {
    final v = Money.parseMinor(_amount.text);
    return (v == null || v <= 0) ? null : v;
  }

  Future<void> _save(DateTime today) async {
    final amount = _amountMinor;
    if (amount == null || _saving) return;
    setState(() => _saving = true);
    final service = ref.read(expenseServiceProvider);
    final date = _date ?? today;
    if (_editing) {
      await service.edit(
        widget.existing!.id,
        amountMinor: amount,
        spentOn: date,
        categoryId: _categoryId,
        note: _note.text,
      );
    } else {
      await service.add(
        amountMinor: amount,
        spentOn: date,
        categoryId: _categoryId,
        note: _note.text,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    try {
      await ref.read(expenseServiceProvider).delete(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    } on PaymentLinkedExpenseException {
      // The button is hidden for these; nothing else to do.
    }
  }

  Future<void> _markUnpaid() async {
    final e = widget.existing!;
    final done = await confirmMarkUnpaid(
      context,
      ref,
      paymentId: e.paymentId!,
      title: e.note ?? categoryName(null),
    );
    if (done && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final date = _date ?? today;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final linked = widget.existing?.paymentId != null;
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
            Text(
              _editing ? l.mnEditExpense : l.mnAddExpense,
              style: theme.textTheme.titleLarge,
            ),
            SizedBox(height: Tokens.spaceM),
            TextField(
              key: const ValueKey('expense-amount'),
              controller: _amount,
              autofocus: !_editing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                prefixText: Money.prefix,
                hintText: '0',
                border: const OutlineInputBorder(),
                errorText: _amount.text.isNotEmpty && _amountMinor == null
                    ? l.mnAmountError
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: Tokens.spaceM),
            Text(l.mnCategory, style: theme.textTheme.labelLarge),
            SizedBox(height: Tokens.spaceS),
            Wrap(
              spacing: Tokens.spaceS,
              runSpacing: Tokens.spaceXs,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    key: ValueKey('expense-category-${c.systemKey ?? c.id}'),
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
            SizedBox(height: Tokens.spaceS),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l.mnDate),
              subtitle: Text(relativeDay(date, now)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(today.year - 2),
                  lastDate: today, // expenses are already spent
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            // Expenses are money already spent; a bill due later goes to
            // the Forecast instead (PBI-038 F-05).
            if (!_editing)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('expense-to-bill'),
                  onPressed: () {
                    final nav = Navigator.of(context);
                    final host = nav.context;
                    nav.pop();
                    showBillSheet(host);
                  },
                  icon: const Icon(Icons.event_note_outlined),
                  label: Text(l.mnNotPaidYet),
                ),
              ),
            TextField(
              key: const ValueKey('expense-note'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l.mnNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            SizedBox(height: Tokens.spaceM),
            Row(
              children: [
                if (_editing && !linked)
                  TextButton.icon(
                    key: const ValueKey('expense-delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.mnDelete),
                  ),
                if (linked)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.mnLinkedNote,
                          key: const ValueKey('expense-linked-note'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        // The only way to remove a payment's expense is to
                        // reverse the payment itself (PBI-038 F-06).
                        TextButton.icon(
                          key: const ValueKey('expense-mark-unpaid'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _markUnpaid,
                          icon: const Icon(Icons.undo),
                          label: Text(l.mnMarkUnpaid),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                FilledButton(
                  key: const ValueKey('expense-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, Tokens.minTouchTarget),
                  ),
                  onPressed: _amountMinor == null || _saving
                      ? null
                      : () => _save(today),
                  child: Text(_editing ? l.mnSave : l.mnAdd),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
