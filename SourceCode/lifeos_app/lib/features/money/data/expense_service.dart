import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../domain/money_rules.dart';

/// Thrown when an expense logged from a payment would be deleted.
class PaymentLinkedExpenseException implements Exception {
  const PaymentLinkedExpenseException(this.expenseId);
  final String expenseId;

  @override
  String toString() =>
      'Expense $expenseId was logged from a payment; undo the payment instead';
}

/// Expense use-cases for PBI-018. Writes go through [Repositories].
class ExpenseService {
  ExpenseService(this._repos);

  final Repositories _repos;

  Future<Expense> add({
    required int amountMinor,
    required DateTime spentOn,
    String? categoryId,
    String? note,
  }) {
    _checkAmount(amountMinor);
    return _repos.expenses.insert(
      ExpensesCompanion.insert(
        amountMinor: amountMinor,
        spentOn: isoDate(spentOn),
        categoryId: Value(categoryId),
        note: Value(_clean(note)),
      ),
    );
  }

  /// Edits amount, category, date or note. The payment link is never
  /// touched, so completion-chain expenses keep it (AC5).
  Future<Expense> edit(
    String id, {
    required int amountMinor,
    required DateTime spentOn,
    String? categoryId,
    String? note,
  }) {
    _checkAmount(amountMinor);
    return _repos.expenses.update(
      id,
      ExpensesCompanion(
        amountMinor: Value(amountMinor),
        spentOn: Value(isoDate(spentOn)),
        categoryId: Value(categoryId),
        note: Value(_clean(note)),
        // payment_id deliberately absent.
      ),
    );
  }

  /// Soft-deletes a manual expense. Payment-linked ones are refused.
  Future<void> delete(String id) async {
    final e = await _repos.expenses.getById(id);
    if (e == null) throw StateError('Expense $id not found');
    if (e.paymentId != null) throw PaymentLinkedExpenseException(id);
    await _repos.expenses.softDelete(id);
  }

  static void _checkAmount(int amountMinor) {
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor', 'must be > 0');
    }
  }

  static String? _clean(String? note) {
    final t = note?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
