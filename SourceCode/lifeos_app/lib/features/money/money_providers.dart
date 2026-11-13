import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import 'data/expense_service.dart';
import 'data/sms_transaction_service.dart';

final expenseServiceProvider = Provider<ExpenseService>(
  (ref) => ExpenseService(ref.watch(repositoriesProvider)),
);

final smsTransactionServiceProvider = Provider<SmsTransactionService>(
  (ref) => SmsTransactionService(ref.watch(repositoriesProvider)),
);

/// Every non-deleted expense, live.
final allExpensesProvider = StreamProvider<List<Expense>>(
  (ref) => ref.watch(repositoriesProvider).expenses.watchAll(),
);

/// Every non-deleted category, live (system categories first by seed order).
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(repositoriesProvider).categories.watchAll(),
);

/// All SMS transactions, live.
final smsTransactionsProvider = StreamProvider<List<SmsTransaction>>(
  (ref) => ref.watch(repositoriesProvider).smsTransactions.watchAll(),
);

/// Unlogged debit SMS transactions (for the pending list).
final pendingSmsTransactionsProvider = FutureProvider<List<SmsTransaction>>(
  (ref) async {
    final service = ref.watch(smsTransactionServiceProvider);
    return service.getTransactions(onlyUnlogged: true);
  },
);
