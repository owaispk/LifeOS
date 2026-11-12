import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../core/now_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/hero_card.dart';
import '../../shared/widgets/stat_tile.dart';
import '../atc/atc_providers.dart';
import 'domain/forecast.dart';
import 'domain/money_rules.dart';
import 'money_providers.dart';
import 'ui/bill_sheet.dart';
import 'ui/category_breakdown.dart';
import 'ui/category_colors.dart';
import 'ui/expense_sheet.dart';
import 'ui/forecast_view.dart';
import 'ui/paid_sheet.dart';

/// How many days of expenses the overview lists before "See all".
const overviewDays = 3;

/// How many unpaid bills "Coming up" shows.
const comingUpLimit = 3;

/// 4.1 MONEY — Month Overview (UI flow §4.1), compact dense-summary layout
/// (PBI-038 F-02, Design/design-system.md §4.10): hero card with the month
/// total, change vs last month and what's left of the salary; three stat
/// tiles; spending by category; bills still to pay; expenses by day.
class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  DateTime? _month; // null = current month
  bool _forecast = false; // Overview · Forecast (PBI-019)
  bool _allDays = false; // "See all expenses"

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
      onChanged: (m) => setState(() {
        _month = m;
        _allDays = false;
      }),
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
              onSelectionChanged: (s) => _showForecast(s.first, month, current),
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
              data: (all) => _Overview(
                summary: summarize(all, categories, month),
                categories: categories,
                now: now,
                header: switcher,
                allDays: _allDays,
                onSeeAll: () => setState(() => _allDays = true),
                onForecast: () => _showForecast(true, month, current),
              ),
            ),
    );
  }

  void _showForecast(bool on, DateTime month, DateTime current) {
    setState(() {
      _forecast = on;
      if (!_forecast && month.isAfter(current)) _month = null;
    });
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({
    required this.summary,
    required this.categories,
    required this.now,
    required this.header,
    required this.allDays,
    required this.onSeeAll,
    required this.onForecast,
  });

  final MonthSummary summary;
  final List<Category> categories;
  final DateTime now;
  final Widget header;
  final bool allDays;
  final VoidCallback onSeeAll;
  final VoidCallback onForecast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final month = summary.month;
    final isCurrent = month == monthStart(now);
    final settings = ref.watch(userSettingsRowProvider).value;
    final forecast = forecastFor(
      month,
      rules: ref.watch(atcRulesProvider).value ?? const <AtcRule>[],
      payments: ref.watch(allPaymentsProvider).value ?? const <Payment>[],
      now: now,
      salaryMinor: settings?.salaryMinor,
      salaryDay: settings?.salaryDay,
    );
    final days = _byDay(summary.expenses);
    final shownDays = allDays ? days : days.take(overviewDays).toList();

    return ListView(
      key: const ValueKey('money-list'),
      padding: EdgeInsets.only(bottom: Tokens.listEnd),
      children: [
        header,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
          child: _Hero(
            summary: summary,
            isCurrent: isCurrent,
            salaryMinor: settings?.salaryMinor,
            onAddSalary: settings == null
                ? null
                : () => editSalary(context, ref, settings),
          ),
        ),
        if (summary.expenses.isNotEmpty) ...[
          SizedBox(height: Tokens.spaceS),
          Padding(
            key: const ValueKey('money-stats'),
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: _Stats(summary: summary, forecast: forecast, now: now),
          ),
          _SectionHeader(l.mnSpendingByCategory),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: CategoryBreakdown(
              slices: summary.slices,
              totalMinor: summary.totalMinor,
            ),
          ),
        ],
        if (isCurrent)
          _ComingUp(forecast: forecast, now: now, onForecast: onForecast),
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
          for (final d in shownDays) ...[
            _SectionHeader(
              relativeDay(d.day, now),
              trailing: Money.format(d.totalMinor),
              key: ValueKey('money-day-${isoDate(d.day)}'),
            ),
            for (final e in d.expenses)
              _ExpenseRow(
                expense: e,
                category: categories
                    .where((c) => c.id == e.categoryId)
                    .firstOrNull,
              ),
          ],
          if (shownDays.length < days.length)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Tokens.spaceS),
                child: TextButton(
                  key: const ValueKey('money-see-all'),
                  onPressed: onSeeAll,
                  child: Text(l.mnSeeAllExpenses(summary.expenses.length)),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// One day of the expense list, with its total.
class _Day {
  _Day(this.day);
  final DateTime day;
  final expenses = <Expense>[];
  int get totalMinor => expenses.fold(0, (s, e) => s + e.amountMinor);
}

/// [expenses] (newest first) grouped by the day they were spent.
List<_Day> _byDay(List<Expense> expenses) {
  final days = <String, _Day>{};
  for (final e in expenses) {
    days
        .putIfAbsent(e.spentOn, () => _Day(parseIsoDate(e.spentOn)))
        .expenses
        .add(e);
  }
  return days.values.toList();
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

/// Hero card: the month total, the change vs last month as a chip, and —
/// with a salary set — how much of it is left (or a button to add one).
class _Hero extends StatelessWidget {
  const _Hero({
    required this.summary,
    required this.isCurrent,
    required this.salaryMinor,
    required this.onAddSalary,
  });

  final MonthSummary summary;
  final bool isCurrent;
  final int? salaryMinor;
  final VoidCallback? onAddSalary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = context.colors;
    final total = summary.totalMinor;
    final salary = salaryMinor;

    Widget? footer;
    if (salary != null && salary > 0) {
      final share = total / salary;
      final left = salary - total;
      footer = CaptionedProgress(
        key: const ValueKey('month-salary'),
        fraction: share,
        color: share > 1
            ? colors.danger
            : share > 0.85
            ? colors.warning
            : theme.colorScheme.primary,
        captionColor: theme.colorScheme.onPrimaryContainer,
        caption: left >= 0
            ? l.mnSalaryLeft(Money.format(left), Money.format(salary))
            : l.mnSalaryOver(Money.format(-left), Money.format(salary)),
      );
    } else if (isCurrent && onAddSalary != null) {
      footer = Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: const ValueKey('month-add-salary'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            padding: EdgeInsets.zero,
          ),
          onPressed: onAddSalary,
          icon: const Icon(Icons.payments_outlined),
          label: Text(l.mnAddSalaryLeft),
        ),
      );
    }

    return HeroCard(
      key: const ValueKey('money-hero'),
      label: isCurrent
          ? l.mnSpentThisMonth
          : l.mnSpentIn(formatMonth(summary.month)),
      value: Money.format(total),
      valueKey: const ValueKey('month-total'),
      chip: _DeltaChip(summary: summary),
      footer: footer,
    );
  }
}

/// "↓ 12% vs Oct": spending up is a warning, down a success; icon and
/// words carry the meaning, the colour only repeats it.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.summary});
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = context.colors;
    final prev = shortMonth(addMonths(summary.month, -1));
    final delta = summary.delta;
    final neutral = (
      theme.colorScheme.surfaceContainerHigh,
      theme.colorScheme.onSurfaceVariant,
    );
    final (
      IconData icon,
      String text,
      (Color, Color) tone,
    ) = switch (delta.kind) {
      DeltaKind.none => (Icons.remove, '', neutral),
      DeltaKind.newSpend => (
        Icons.fiber_new_outlined,
        l.mnDeltaNew(prev),
        neutral,
      ),
      DeltaKind.same => (Icons.trending_flat, l.mnDeltaSame(prev), neutral),
      DeltaKind.up => (
        Icons.arrow_upward,
        l.mnDeltaVs('${delta.percent}', prev),
        (colors.warningContainer, colors.onWarningContainer),
      ),
      DeltaKind.down => (
        Icons.arrow_downward,
        l.mnDeltaVs('${delta.percent}', prev),
        (colors.successContainer, colors.onSuccessContainer),
      ),
    };
    if (delta.kind == DeltaKind.none) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('month-delta'),
      padding: EdgeInsets.symmetric(
        horizontal: Tokens.spaceS,
        vertical: Tokens.spaceXxs,
      ),
      decoration: BoxDecoration(
        color: tone.$1,
        borderRadius: BorderRadius.circular(Tokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Tokens.iconS, color: tone.$2),
          SizedBox(width: Tokens.spaceXxs),
          // Long words (Urdu, large text) wrap instead of overflowing.
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(color: tone.$2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per day · Biggest · Bills paid.
class _Stats extends StatelessWidget {
  const _Stats({
    required this.summary,
    required this.forecast,
    required this.now,
  });

  final MonthSummary summary;
  final Forecast forecast;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final month = summary.month;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daysSoFar = month == monthStart(now) ? now.day : daysInMonth;
    // Whole rupees: paise add noise to an average.
    final perDay = (summary.totalMinor / daysSoFar / 100).round() * 100;
    final biggest = summary.slices.firstOrNull;
    final paid = forecast.items
        .where((i) => i.status == ForecastStatus.paid)
        .length;
    return StatTileRow(
      tiles: [
        StatTile(label: l.mnStatPerDay, value: Money.format(perDay)),
        StatTile(
          label: l.mnStatBiggest,
          value: biggest == null ? '—' : biggest.name,
        ),
        StatTile(
          label: l.mnStatBillsPaid,
          value: forecast.items.isEmpty
              ? '—'
              : l.mnBillsPaidValue(paid, forecast.items.length),
        ),
      ],
    );
  }
}

/// Bills still to pay this month: the next few, the amount left, a link to
/// the Forecast and a way to add a one-off bill (F-05).
class _ComingUp extends ConsumerWidget {
  const _ComingUp({
    required this.forecast,
    required this.now,
    required this.onForecast,
  });

  final Forecast forecast;
  final DateTime now;
  final VoidCallback onForecast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = context.colors;
    final unpaid =
        forecast.items.where((i) => i.status != ForecastStatus.paid).toList()
          ..sort((a, b) => a.due.compareTo(b.due));
    return Column(
      key: const ValueKey('money-coming-up'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          l.mnComingUp,
          trailing: unpaid.isEmpty
              ? null
              : l.mnStillToPay(Money.format(forecast.remainingMinor)),
          action: l.mnSeeForecast,
          onAction: onForecast,
        ),
        if (unpaid.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: Text(
              l.mnNothingDue,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final i in unpaid.take(comingUpLimit))
          ListTile(
            key: ValueKey(
              'coming-${i.paymentId ?? '${i.ruleId}-${i.due.day}'}',
            ),
            minTileHeight: Tokens.rowTwoLine,
            leading: Icon(
              i.status == ForecastStatus.overdue
                  ? Icons.warning_amber_rounded
                  : Icons.event_outlined,
              color: i.status == ForecastStatus.overdue
                  ? colors.danger
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${relativeDay(i.due, now)} · '
              '${i.status == ForecastStatus.overdue ? l.mnStatusOverdue : l.mnStatusUpcoming}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: i.status == ForecastStatus.overdue
                  ? TextStyle(color: colors.danger)
                  : null,
            ),
            trailing: Text(
              i.amountMinor == null
                  ? l.mnAmountPending
                  : '${i.estimated ? '~' : ''}${Money.format(i.amountMinor!)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: i.paymentId == null
                ? onForecast
                : () async {
                    final p = await ref
                        .read(repositoriesProvider)
                        .payments
                        .getById(i.paymentId!);
                    if (p != null && context.mounted) {
                      await payWithChain(context, ref, p);
                    }
                  },
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.spaceS),
            child: TextButton.icon(
              key: const ValueKey('money-add-bill'),
              onPressed: () => showBillSheet(context),
              icon: const Icon(Icons.add),
              label: Text(l.mnAddBill),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.category});

  final Expense expense;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = expense.note;
    return ListTile(
      key: ValueKey('expense-${expense.id}'),
      minTileHeight: Tokens.rowOneLine,
      onTap: () => showExpenseSheet(context, existing: expense),
      leading: CircleAvatar(
        radius: Tokens.iconL / 2 + Tokens.spaceXxs,
        backgroundColor: categoryColor(
          context,
          colorSlotFor(category),
        ).withValues(alpha: 0.18),
        child: Text(category?.icon ?? '❔'),
      ),
      // The note says what it was; the category says what kind.
      title: Text(
        note == null || note.isEmpty ? categoryName(category) : note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: note == null || note.isEmpty
          ? null
          : Text(
              categoryName(category),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expense.paymentId != null)
            Padding(
              padding: EdgeInsetsDirectional.only(end: Tokens.spaceXs),
              child: Text(
                '⚡',
                semanticsLabel: context.l10n.mnLoggedFromPayment,
              ),
            ),
          if (expense.receiptDocumentId != null)
            Padding(
              padding: EdgeInsetsDirectional.only(end: Tokens.spaceXs),
              child: Icon(
                Icons.attach_file,
                size: Tokens.iconS,
                semanticLabel: context.l10n.mnReceiptAttached,
              ),
            ),
          Text(
            Money.format(expense.amountMinor),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sentence-case section header (design decision D2): title, optional grey
/// figure, optional text action with a full-size tap area.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.action,
    this.onAction,
  });

  final String title;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: Tokens.gutter,
          end: action == null ? Tokens.gutter : Tokens.spaceXs,
          top: action == null ? Tokens.spaceL : Tokens.spaceS,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // With an action beside it, the figure goes under the
                  // title so neither has to wrap on a small phone.
                  if (trailing != null && action != null)
                    Text(
                      trailing!,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                ],
              ),
            ),
            if (trailing != null && action == null)
              Flexible(
                child: Text(
                  trailing!,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      ),
    );
  }
}
