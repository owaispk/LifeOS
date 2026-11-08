import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../../shared/widgets/empty_state.dart';
import 'domain/money_rules.dart';
import 'money_providers.dart';
import 'ui/category_breakdown.dart';
import 'ui/category_colors.dart';
import 'ui/expense_sheet.dart';

/// 4.1 MONEY — Month Overview (UI flow §4.1).
class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  DateTime? _month; // null = current month

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    final current = monthStart(now);
    final month = _month ?? current;
    final expenses = ref.watch(allExpensesProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Money')),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyState(
          emoji: '⚠️',
          title: "Money isn't available",
          message: 'Local data could not be opened on this device.',
        ),
        data: (all) {
          final summary = summarize(all, categories, month);
          return ListView(
            key: const ValueKey('money-list'),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _MonthSwitcher(
                month: month,
                canGoNext: month.isBefore(current),
                onChanged: (m) => setState(() => _month = m),
              ),
              _Hero(summary: summary),
              if (summary.expenses.isEmpty)
                EmptyState(
                  inList: true,
                  emoji: '💰',
                  title: 'No expenses in ${formatMonth(month)}',
                  message: 'Paid bills and quick expenses will add up here.',
                  actionLabel: '💸 Add expense',
                  onAction: () => showExpenseSheet(context),
                )
              else ...[
                const _SectionTitle('Spending by category'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.spaceM,
                  ),
                  child: CategoryBreakdown(
                    slices: summary.slices,
                    totalMinor: summary.totalMinor,
                  ),
                ),
                _SectionTitle('Expenses · ${summary.expenses.length}'),
                for (final e in summary.expenses)
                  _ExpenseRow(
                    expense: e,
                    category: categories
                        .where((c) => c.id == e.categoryId)
                        .firstOrNull,
                    now: now,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.canGoNext,
    required this.onChanged,
  });

  final DateTime month;
  final bool canGoNext;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceS),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('month-prev'),
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(addMonths(month, -1)),
          ),
          Expanded(
            child: Text(
              formatMonth(month),
              key: const ValueKey('month-label'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const ValueKey('month-next'),
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoNext ? () => onChanged(addMonths(month, 1)) : null,
          ),
        ],
      ),
    );
  }
}

/// Big number: spent this month + delta vs last month.
class _Hero extends StatelessWidget {
  const _Hero({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prev = shortMonth(addMonths(summary.month, -1));
    final delta = summary.delta;
    final (IconData? icon, String? text) = switch (delta.kind) {
      DeltaKind.none => (null, null),
      DeltaKind.newSpend => (
        Icons.fiber_new_outlined,
        'New · nothing in $prev',
      ),
      DeltaKind.same => (Icons.trending_flat, 'Same as $prev'),
      DeltaKind.up => (Icons.arrow_upward, '${delta.percent}% vs $prev'),
      DeltaKind.down => (Icons.arrow_downward, '${delta.percent}% vs $prev'),
    };
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.spaceM,
        Tokens.spaceS,
        Tokens.spaceM,
        Tokens.spaceM,
      ),
      child: Column(
        children: [
          Text(
            'Spent',
            style: theme.textTheme.labelLarge?.copyWith(color: muted),
          ),
          Text(
            Money.format(summary.totalMinor),
            key: const ValueKey('month-total'),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (text != null)
            Row(
              key: const ValueKey('month-delta'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: Tokens.spaceXs),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.category,
    required this.now,
  });

  final Expense expense;
  final Category? category;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = category?.name ?? 'Uncategorised';
    final when = relativeDay(parseIsoDate(expense.spentOn), now);
    return ListTile(
      key: ValueKey('expense-${expense.id}'),
      minTileHeight: 64,
      onTap: () => showExpenseSheet(context, existing: expense),
      leading: CircleAvatar(
        backgroundColor: categoryColor(
          context,
          colorSlotFor(category),
        ).withValues(alpha: 0.18),
        child: Text(category?.icon ?? '❔'),
      ),
      title: Text(title),
      subtitle: Text(
        [when, if (expense.note != null) expense.note!].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expense.paymentId != null)
            const Padding(
              padding: EdgeInsets.only(right: Tokens.spaceXs),
              child: Text('⚡', semanticsLabel: 'Logged from a payment'),
            ),
          if (expense.receiptDocumentId != null)
            const Padding(
              padding: EdgeInsets.only(right: Tokens.spaceXs),
              child: Icon(
                Icons.attach_file,
                size: 18,
                semanticLabel: 'Receipt attached',
              ),
            ),
          Text(
            Money.format(expense.amountMinor),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.spaceM,
          Tokens.spaceL,
          Tokens.spaceM,
          Tokens.spaceS,
        ),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
