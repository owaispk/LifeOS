import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/now_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/data_providers.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../atc/atc_providers.dart';
import '../domain/forecast.dart';
import 'paid_sheet.dart';

final userSettingsRowProvider = StreamProvider<UserSettingsRow?>(
  (ref) => ref
      .watch(repositoriesProvider)
      .userSettings
      .watchAll()
      .map((l) => l.firstOrNull),
);

/// 4.2 Monthly Forecast (PBI-019).
class ForecastView extends ConsumerWidget {
  const ForecastView({super.key, required this.month, required this.header});

  final DateTime month;

  /// The month switcher, shared with the Overview.
  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final rules = ref.watch(atcRulesProvider).value ?? const <AtcRule>[];
    final payments = ref.watch(allPaymentsProvider).value ?? const <Payment>[];
    final settings = ref.watch(userSettingsRowProvider).value;
    final f = forecastFor(
      month,
      rules: rules,
      payments: payments,
      now: now,
      salaryMinor: settings?.salaryMinor,
      salaryDay: settings?.salaryDay,
    );
    final monthName = formatMonth(month).split(' ').first;
    final l = context.l10n;

    return ListView(
      key: const ValueKey('forecast-list'),
      padding: EdgeInsets.only(bottom: Tokens.listEnd),
      children: [
        header,
        if (f.items.isEmpty)
          EmptyState(
            inList: true,
            emoji: '📆',
            title: l.mnNoFixedTitle,
            message: l.mnNoFixedBody,
          )
        else ...[
          // Digest card (PBI-019; the notification is PBI-023).
          Card(
            key: const ValueKey('forecast-digest'),
            margin: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: Padding(
              padding: EdgeInsets.all(Tokens.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.mnDigest(
                      monthName,
                      Money.format(f.totalMinor),
                      f.items.length,
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                  SizedBox(height: Tokens.spaceXs),
                  Text(
                    l.mnTotals(
                      Money.format(f.totalMinor),
                      Money.format(f.paidMinor),
                      Money.format(f.remainingMinor),
                    ),
                    key: const ValueKey('forecast-totals'),
                  ),
                  SizedBox(height: Tokens.spaceXs),
                  if (f.salaryPercent != null)
                    Text(
                      l.mnSalaryShare('${f.salaryPercent}'),
                      key: const ValueKey('forecast-salary'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    TextButton.icon(
                      key: const ValueKey('forecast-set-salary'),
                      onPressed: () => _editSalary(context, ref, settings),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(l.mnAddSalary),
                    ),
                ],
              ),
            ),
          ),
          _CalendarStrip(month: month, items: f.items, now: now),
          for (final i in f.items) _ForecastRow(item: i, now: now),
          if (f.salaryPercent != null)
            Center(
              child: TextButton(
                onPressed: () => _editSalary(context, ref, settings),
                child: Text(l.mnChangeSalary),
              ),
            ),
        ],
      ],
    );
  }
}

Future<void> _editSalary(
  BuildContext context,
  WidgetRef ref,
  UserSettingsRow? settings,
) async {
  if (settings == null) return;
  final amount = TextEditingController(
    text: settings.salaryMinor == null
        ? ''
        : Money.formatPlain(settings.salaryMinor!),
  );
  var day = settings.salaryDay ?? 1;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(context.l10n.mnYourSalary),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('salary-amount'),
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.l10n.mnMonthlySalary,
                prefixText: Money.prefix,
              ),
            ),
            DropdownButtonFormField<int>(
              key: const ValueKey('salary-day'),
              initialValue: day,
              decoration: InputDecoration(labelText: context.l10n.mnPaidOnDay),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('$d')),
              ],
              onChanged: (d) => setState(() => day = d ?? day),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('salary-save'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.mnSave),
          ),
        ],
      ),
    ),
  );
  if (saved != true) return;
  await ref
      .read(repositoriesProvider)
      .userSettings
      .update(
        settings.id,
        UserSettingsCompanion(
          salaryMinor: Value(Money.parseMinor(amount.text)),
          salaryDay: Value(day),
        ),
      );
}

/// The month's days with a dot on each due day; status is spelled out in
/// the list below (never colour alone).
class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({
    required this.month,
    required this.items,
    required this.now,
  });

  final DateTime month;
  final List<ForecastItem> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final dueDays = {for (final i in items) i.due.day};
    return SizedBox(
      height: 64,
      child: ListView.builder(
        key: const ValueKey('forecast-calendar'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: Tokens.gutter,
          vertical: Tokens.spaceS,
        ),
        itemCount: days,
        itemBuilder: (context, i) {
          final d = i + 1;
          final isToday =
              now.year == month.year &&
              now.month == month.month &&
              now.day == d;
          return Container(
            width: 36,
            margin: EdgeInsetsDirectional.only(end: Tokens.spaceXs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isToday ? Border.all(color: scheme.primary) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$d'),
                SizedBox(height: Tokens.spaceXxs),
                Container(
                  key: dueDays.contains(d) ? ValueKey('due-dot-$d') : null,
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dueDays.contains(d)
                        ? scheme.primary
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ForecastRow extends ConsumerWidget {
  const _ForecastRow({required this.item, required this.now});
  final ForecastItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final amount = item.amountMinor == null
        ? l.mnAmountPending
        : '${item.estimated ? '~' : ''}${Money.format(item.amountMinor!)}';
    final (label, color) = switch (item.status) {
      ForecastStatus.paid => (l.mnStatusPaid, theme.colorScheme.primary),
      ForecastStatus.overdue => (l.mnStatusOverdue, theme.colorScheme.error),
      ForecastStatus.upcoming => (
        item.projected ? l.mnStatusUpcomingPlanned : l.mnStatusUpcoming,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return ListTile(
      key: ValueKey(
        'forecast-${item.paymentId ?? '${item.ruleId}-${item.due.day}'}',
      ),
      title: Text(item.title),
      subtitle: Text(
        '${relativeDay(item.due, now)} · $label',
        style: TextStyle(color: color),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(amount, style: theme.textTheme.bodyLarge),
          if (item.paymentId != null && item.status != ForecastStatus.paid)
            IconButton(
              key: ValueKey('mark-paid-${item.paymentId}'),
              tooltip: l.mnMarkPaid,
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () async {
                final p = await ref
                    .read(repositoriesProvider)
                    .payments
                    .getById(item.paymentId!);
                if (p != null && context.mounted) {
                  await payWithChain(context, ref, p);
                }
              },
            ),
        ],
      ),
    );
  }
}
