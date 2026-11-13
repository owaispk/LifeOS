import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/data_providers.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/sms_reader.dart';
import '../domain/money_rules.dart';
import '../money_providers.dart';
import 'expense_sheet.dart';

/// SMS Transactions list screen (PBI-040).
class SmsTransactionsScreen extends ConsumerStatefulWidget {
  const SmsTransactionsScreen({super.key});

  @override
  ConsumerState<SmsTransactionsScreen> createState() =>
      _SmsTransactionsScreenState();
}

class _SmsTransactionsScreenState extends ConsumerState<SmsTransactionsScreen> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final transactions = ref.watch(smsTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.smsTitle),
        actions: [
          if (SmsReader.isAvailable)
            IconButton(
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: l.smsSyncNow,
              onPressed: _syncing ? null : _syncSms,
            ),
        ],
      ),
      body: !SmsReader.isAvailable
          ? _IosUnavailable()
          : transactions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                emoji: '⚠️',
                title: l.smsUnavailableTitle,
                message: l.smsUnavailableBody,
              ),
              data: (txns) => txns.isEmpty
                  ? EmptyState(
                      inList: true,
                      emoji: '📱',
                      title: l.smsEmptyTitle,
                      message: l.smsEmptyBody,
                      actionLabel: l.smsSyncNow,
                      onAction: _syncSms,
                    )
                  : _TransactionList(transactions: txns),
            ),
    );
  }

  Future<void> _syncSms() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    try {
      // Check permission first
      final hasPermission = await SmsReader.hasPermission();
      if (!hasPermission) {
        final granted = await SmsReader.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.smsPermissionDenied)),
            );
          }
          return;
        }
      }

      // Read bank SMS
      final messages = await SmsReader.readBankSms(limit: 200);

      // Process them
      final service = ref.read(smsTransactionServiceProvider);
      final count = await service.processSmsMessages(messages);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? context.l10n.smsSyncSuccess(count)
                : context.l10n.smsSyncNoNew),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

/// iOS unavailable screen.
class _IosUnavailable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyState(
      inList: true,
      emoji: '🍎',
      title: l.smsIosTitle,
      message: l.smsIosBody,
    );
  }
}

/// Transaction list grouped by date.
class _TransactionList extends ConsumerWidget {
  const _TransactionList({required this.transactions});

  final List<SmsTransaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = _groupByDate(transactions);
    final categories = ref.watch(categoriesProvider).value ?? [];

    return ListView.builder(
      padding: EdgeInsets.only(bottom: Tokens.listEnd),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(date: group.date, totalMinor: group.totalMinor),
            for (final txn in group.transactions)
              _TransactionRow(
                transaction: txn,
                categories: categories,
              ),
          ],
        );
      },
    );
  }

  List<_DateGroup> _groupByDate(List<SmsTransaction> transactions) {
    final groups = <String, _DateGroup>{};
    for (final txn in transactions) {
      final date = DateTime.fromMillisecondsSinceEpoch(txn.smsTimestamp);
      final key = isoDate(date);
      groups.putIfAbsent(key, () => _DateGroup(date));
      groups[key]!.transactions.add(txn);
    }
    return groups.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

class _DateGroup {
  _DateGroup(this.date);
  final DateTime date;
  final transactions = <SmsTransaction>[];

  int get totalMinor => transactions
      .where((t) => t.transactionType == 'debit')
      .fold(0, (sum, t) => sum + t.amountMinor);
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.totalMinor});

  final DateTime date;
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Tokens.gutter,
        Tokens.spaceL,
        Tokens.gutter,
        Tokens.spaceXs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              relativeDay(date, DateTime.now()),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (totalMinor > 0)
            Text(
              Money.format(totalMinor),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({
    required this.transaction,
    required this.categories,
  });

  final SmsTransaction transaction;
  final List<Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l = context.l10n;
    final isDebit = transaction.transactionType == 'debit';
    final isLogged = transaction.expenseId != null;
    final time = DateTime.fromMillisecondsSinceEpoch(transaction.smsTimestamp);

    return ListTile(
      key: ValueKey('sms-${transaction.id}'),
      minTileHeight: Tokens.rowTwoLine,
      leading: CircleAvatar(
        backgroundColor: isDebit
            ? colors.danger.withValues(alpha: 0.12)
            : colors.success.withValues(alpha: 0.12),
        child: Icon(
          isDebit ? Icons.arrow_upward : Icons.arrow_downward,
          color: isDebit ? colors.danger : colors.success,
          size: Tokens.iconM,
        ),
      ),
      title: Text(
        transaction.merchant ?? transaction.smsSender,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            formatTime(time),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (transaction.accountMasked != null) ...[
            Text(
              ' · ',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            Text(
              transaction.accountMasked!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (isLogged) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.check_circle,
              size: Tokens.iconXs,
              color: colors.success,
            ),
            const SizedBox(width: 2),
            Text(
              l.smsLogged,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.success,
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        '${isDebit ? '-' : '+'}${Money.format(transaction.amountMinor)}',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDebit ? colors.danger : colors.success,
        ),
      ),
      onTap: isLogged || !isDebit
          ? null
          : () => _showLogOptions(context, ref),
    );
  }

  void _showLogOptions(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(l.smsLogAsExpense),
              onTap: () {
                Navigator.pop(context);
                _logAsExpense(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: Text(l.smsIgnore),
              onTap: () async {
                Navigator.pop(context);
                final service = ref.read(smsTransactionServiceProvider);
                await service.ignoreTransaction(transaction.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _logAsExpense(BuildContext context, WidgetRef ref) {
    // Open expense sheet pre-filled with SMS data
    final date = DateTime.fromMillisecondsSinceEpoch(transaction.smsTimestamp);
    showExpenseSheet(
      context,
      prefillAmount: transaction.amountMinor,
      prefillNote: transaction.merchant,
      prefillDate: date,
      onSaved: (expense) async {
        // Link the expense to the SMS transaction
        final service = ref.read(smsTransactionServiceProvider);
        await ref.read(repositoriesProvider).smsTransactions.update(
          transaction.id,
          SmsTransactionsCompanion(
            expenseId: Value(expense.id),
            autoLogged: const Value(false),
          ),
        );
      },
    );
  }
}

/// Format time as HH:mm.
String formatTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
