import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
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
import 'ui/forecast_view.dart';

/// 4.1 MONEY — Month Overview (UI flow §4.1).
class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  DateTime? _month; // null = current month
  bool _forecast = false; // Overview · Forecast (PBI-019)

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    final current = monthStart(now);
    final month = _month ?? current;
    final expenses = ref.watch(allExpensesProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final l = context.l10n;

    final switcher = _MonthSwitcher(
      month: month,
      // The forecast can look ahead a year; the overview stops at today.
      canGoNext: _forecast
          ? month.isBefore(addMonths(current, 12))
          : month.isBefore(current),
      onChanged: (m) => setState(() => _month = m),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.mnTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Tokens.gutter,
              0,
              Tokens.gutter,
              Tokens.spaceS,
            ),
            child: SegmentedButton<bool>(
              key: const ValueKey('money-view'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l.mnOverview)),
                ButtonSegment(value: true, label: Text(l.mnForecast)),
              ],
              selected: {_forecast},
              onSelectionChanged: (s) => setState(() {
                _forecast = s.first;
                if (!_forecast && month.isAfter(current)) _month = null;
              }),
            ),
          ),
        ),
      ),
      body: _forecast
          ? ForecastView(month: month, header: switcher)
          : expenses.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                emoji: '⚠️',
                title: l.mnUnavailableTitle,
                message: l.mnUnavailableBody,
              ),
              data: (all) {
                final summary = summarize(all, categories, month);
                return ListView(
                  key: const ValueKey('money-list'),
                  padding: EdgeInsets.only(bottom: Tokens.listEnd),
                  children: [
                    switcher,
                    _Hero(summary: summary),
                    if (summary.expenses.isEmpty)
                      EmptyState(
                        inList: true,
                        emoji: '💰',
                        title: l.mnNoExpensesIn(formatMonth(month)),
                        message: l.mnNoExpensesBody,
                        actionLabel: l.mnAddExpenseAction,
                        onAction: () => showExpenseSheet(context),
                      )
                    else ...[
                      _SectionTitle(l.mnSpendingByCategory),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Tokens.gutter,
                        ),
                        child: CategoryBreakdown(
                          slices: summary.slices,
                          totalMinor: summary.totalMinor,
                        ),
                      ),
                      _SectionTitle(
                        l.mnExpensesCount('${summary.expenses.length}'),
                      ),
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
      padding: EdgeInsets.symmetric(horizontal: Tokens.spaceS),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('month-prev'),
            tooltip: context.l10n.mnPrevMonth,
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
            tooltip: context.l10n.mnNextMonth,
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
    final l = context.l10n;
    final (IconData? icon, String? text) = switch (delta.kind) {
      DeltaKind.none => (null, null),
      DeltaKind.newSpend => (Icons.fiber_new_outlined, l.mnDeltaNew(prev)),
      DeltaKind.same => (Icons.trending_flat, l.mnDeltaSame(prev)),
      DeltaKind.up => (
        Icons.arrow_upward,
        l.mnDeltaVs('${delta.percent}', prev),
      ),
      DeltaKind.down => (
        Icons.arrow_downward,
        l.mnDeltaVs('${delta.percent}', prev),
      ),
    };
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Tokens.gutter,
        Tokens.spaceS,
        Tokens.gutter,
        Tokens.spaceM,
      ),
      child: Column(
        children: [
          Text(
            l.mnSpent,
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
                SizedBox(width: Tokens.spaceXs),
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
    final title = categoryName(category);
    final when = relativeDay(parseIsoDate(expense.spentOn), now);
    return ListTile(
      key: ValueKey('expense-${expense.id}'),
      minTileHeight: Tokens.rowTwoLine,
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
            Padding(
              padding: EdgeInsets.only(right: Tokens.spaceXs),
              child: Text(
                '⚡',
                semanticsLabel: context.l10n.mnLoggedFromPayment,
              ),
            ),
          if (expense.receiptDocumentId != null)
            Padding(
              padding: EdgeInsets.only(right: Tokens.spaceXs),
              child: Icon(
                Icons.attach_file,
                size: 18,
                semanticLabel: context.l10n.mnReceiptAttached,
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
        padding: EdgeInsets.fromLTRB(
          Tokens.gutter,
          Tokens.spaceL,
          Tokens.gutter,
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
