import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import 'data/expense_service.dart';

final expenseServiceProvider = Provider<ExpenseService>(
  (ref) => ExpenseService(ref.watch(repositoriesProvider)),
);

/// Every non-deleted expense, live.
final allExpensesProvider = StreamProvider<List<Expense>>(
  (ref) => ref.watch(repositoriesProvider).expenses.watchAll(),
);

/// Every non-deleted category, live (system categories first by seed order).
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(repositoriesProvider).categories.watchAll(),
);
