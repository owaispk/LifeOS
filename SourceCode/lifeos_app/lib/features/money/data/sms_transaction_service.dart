import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../domain/bank_sms_parser.dart';
import '../domain/money_rules.dart';

/// Thrown when trying to delete an expense linked to an SMS transaction.
class SmsLinkedExpenseException implements Exception {
  const SmsLinkedExpenseException(this.expenseId);
  final String expenseId;

  @override
  String toString() =>
      'Expense $expenseId was logged from SMS; remove the SMS transaction link instead';
}

/// SMS transaction use-cases for PBI-040.
class SmsTransactionService {
  SmsTransactionService(this._repos);

  final Repositories _repos;

  /// Process a list of raw SMS messages and store parsed transactions.
  /// Returns the number of new transactions stored.
  Future<int> processSmsMessages(List<RawSms> messages) async {
    int count = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final sms in messages) {
      final parsed = parseSms(
        sender: sms.sender,
        body: sms.body,
        timestamp: sms.timestamp,
      );

      if (parsed == null) continue;

      // Check for duplicate by hash
      final existing = await _findByHash(parsed.smsHash);
      if (existing != null) continue;

      // Store the transaction
      await _repos.smsTransactions.insert(
        SmsTransactionsCompanion.insert(
          smsSender: parsed.smsSender,
          smsHash: parsed.smsHash,
          amountMinor: parsed.amountMinor,
          transactionType: parsed.transactionType.name,
          merchant: Value(parsed.merchant),
          accountMasked: Value(parsed.accountMasked),
          cardMasked: Value(parsed.cardMasked),
          balanceMinor: Value(parsed.balance),
          smsTimestamp: parsed.smsTimestamp.millisecondsSinceEpoch,
          parsedAt: now,
        ),
      );
      count++;
    }

    return count;
  }

  /// Find a transaction by its hash.
  Future<SmsTransaction?> _findByHash(String hash) async {
    final query = _repos.db.select(_repos.db.smsTransactions)
      ..where((t) => t.smsHash.equals(hash))
      ..where((t) => t.deletedAt.isNull());
    return query.getSingleOrNull();
  }

  /// Get all transactions, optionally filtered.
  Future<List<SmsTransaction>> getTransactions({
    DateTime? since,
    bool includeIgnored = false,
    bool onlyUnlogged = false,
  }) async {
    final query = _repos.db.select(_repos.db.smsTransactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.smsTimestamp)]);

    if (since != null) {
      query.where((t) => t.smsTimestamp.isBiggerOrEqualValue(
        since.millisecondsSinceEpoch,
      ));
    }

    if (!includeIgnored) {
      query.where((t) => t.ignored.equals(false));
    }

    if (onlyUnlogged) {
      query.where((t) => t.expenseId.isNull());
    }

    return query.get();
  }

  /// Get transactions for a specific day.
  Future<List<SmsTransaction>> getTransactionsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final query = _repos.db.select(_repos.db.smsTransactions)
      ..where((t) => t.deletedAt.isNull())
      ..where((t) => t.smsTimestamp.isBiggerOrEqualValue(
        start.millisecondsSinceEpoch,
      ))
      ..where((t) => t.smsTimestamp.isSmallerThanValue(
        end.millisecondsSinceEpoch,
      ))
      ..orderBy([(t) => OrderingTerm.desc(t.smsTimestamp)]);

    return query.get();
  }

  /// Log an SMS transaction as an expense.
  /// Returns the created expense.
  Future<Expense> logAsExpense(
    String transactionId, {
    String? categoryId,
    String? note,
  }) async {
    final txn = await _repos.smsTransactions.getById(transactionId);
    if (txn == null) throw StateError('Transaction $transactionId not found');
    if (txn.expenseId != null) {
      throw StateError('Transaction already logged as expense ${txn.expenseId}');
    }
    if (txn.transactionType != 'debit') {
      throw StateError('Only debit transactions can be logged as expenses');
    }

    // Create the expense
    final expense = await _repos.expenses.insert(
      ExpensesCompanion.insert(
        amountMinor: txn.amountMinor,
        spentOn: isoDate(DateTime.fromMillisecondsSinceEpoch(txn.smsTimestamp)),
        categoryId: Value(categoryId),
        note: Value(note ?? txn.merchant),
      ),
    );

    // Link the expense to the transaction
    await _repos.smsTransactions.update(
      transactionId,
      SmsTransactionsCompanion(
        expenseId: Value(expense.id),
        autoLogged: const Value(false),
      ),
    );

    return expense;
  }

  /// Auto-log a debit transaction as an expense (used when auto-log is enabled).
  Future<Expense?> autoLogTransaction(String transactionId) async {
    final txn = await _repos.smsTransactions.getById(transactionId);
    if (txn == null) return null;
    if (txn.expenseId != null) return null; // Already logged
    if (txn.transactionType != 'debit') return null;
    if (txn.ignored) return null;

    // Guess category from merchant
    final categoryId = await _guessCategoryId(txn.merchant);

    // Create the expense
    final expense = await _repos.expenses.insert(
      ExpensesCompanion.insert(
        amountMinor: txn.amountMinor,
        spentOn: isoDate(DateTime.fromMillisecondsSinceEpoch(txn.smsTimestamp)),
        categoryId: Value(categoryId),
        note: Value(txn.merchant),
      ),
    );

    // Link the expense to the transaction
    await _repos.smsTransactions.update(
      transactionId,
      SmsTransactionsCompanion(
        expenseId: Value(expense.id),
        autoLogged: const Value(true),
      ),
    );

    return expense;
  }

  /// Guess category ID from merchant name.
  Future<String?> _guessCategoryId(String? merchant) async {
    final guess = guessCategory(merchant);
    if (guess == null) return null;

    // Find category with matching system key
    final query = _repos.db.select(_repos.db.categories)
      ..where((c) => c.systemKey.equals(guess))
      ..where((c) => c.deletedAt.isNull());
    final category = await query.getSingleOrNull();
    return category?.id;
  }

  /// Mark a transaction as ignored (user dismissed).
  Future<void> ignoreTransaction(String transactionId) async {
    await _repos.smsTransactions.update(
      transactionId,
      const SmsTransactionsCompanion(ignored: Value(true)),
    );
  }

  /// Unignore a transaction.
  Future<void> unignoreTransaction(String transactionId) async {
    await _repos.smsTransactions.update(
      transactionId,
      const SmsTransactionsCompanion(ignored: Value(false)),
    );
  }

  /// Unlink an expense from a transaction (for undo).
  Future<void> unlinkExpense(String transactionId) async {
    final txn = await _repos.smsTransactions.getById(transactionId);
    if (txn == null) return;
    if (txn.expenseId == null) return;

    // Soft-delete the expense
    await _repos.expenses.softDelete(txn.expenseId!);

    // Remove the link
    await _repos.smsTransactions.update(
      transactionId,
      const SmsTransactionsCompanion(
        expenseId: Value(null),
        autoLogged: Value(false),
      ),
    );
  }

  /// Get today's transaction summary for notification.
  Future<DaySummary> getTodaySummary() async {
    final today = DateTime.now();
    final transactions = await getTransactionsForDay(today);

    int debitCount = 0;
    int debitTotal = 0;
    int creditCount = 0;
    int creditTotal = 0;

    for (final txn in transactions) {
      if (txn.transactionType == 'debit') {
        debitCount++;
        debitTotal += txn.amountMinor;
      } else {
        creditCount++;
        creditTotal += txn.amountMinor;
      }
    }

    return DaySummary(
      date: today,
      debitCount: debitCount,
      debitTotalMinor: debitTotal,
      creditCount: creditCount,
      creditTotalMinor: creditTotal,
    );
  }

  /// Find pending payment tasks that match an SMS transaction.
  /// Match criteria: amount within 5%, due date within 3 days.
  Future<List<Payment>> findMatchingPayments(String transactionId) async {
    final txn = await _repos.smsTransactions.getById(transactionId);
    if (txn == null) return [];
    if (txn.transactionType != 'debit') return [];

    final txnDate = DateTime.fromMillisecondsSinceEpoch(txn.smsTimestamp);
    final minDate = txnDate.subtract(const Duration(days: 3));
    final maxDate = txnDate.add(const Duration(days: 3));

    // Amount tolerance: ±5%
    final minAmount = (txn.amountMinor * 0.95).round();
    final maxAmount = (txn.amountMinor * 1.05).round();

    final query = _repos.db.select(_repos.db.payments)
      ..where((p) => p.status.equals('upcoming'))
      ..where((p) => p.deletedAt.isNull())
      ..where((p) => p.amountMinor.isBiggerOrEqualValue(minAmount))
      ..where((p) => p.amountMinor.isSmallerOrEqualValue(maxAmount));

    final payments = await query.get();

    // Filter by date range
    return payments.where((p) {
      final dueDate = parseIsoDate(p.dueDate);
      return dueDate.isAfter(minDate.subtract(const Duration(days: 1))) &&
          dueDate.isBefore(maxDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Link an SMS transaction to a payment (for auto-complete flow).
  Future<void> linkToPayment(String transactionId, String paymentId) async {
    await _repos.smsTransactions.update(
      transactionId,
      SmsTransactionsCompanion(paymentId: Value(paymentId)),
    );
  }
}

/// Raw SMS message from the platform.
class RawSms {
  const RawSms({
    required this.sender,
    required this.body,
    required this.timestamp,
  });

  final String sender;
  final String body;
  final DateTime timestamp;
}

/// Summary of transactions for a day.
class DaySummary {
  const DaySummary({
    required this.date,
    required this.debitCount,
    required this.debitTotalMinor,
    required this.creditCount,
    required this.creditTotalMinor,
  });

  final DateTime date;
  final int debitCount;
  final int debitTotalMinor;
  final int creditCount;
  final int creditTotalMinor;

  int get totalCount => debitCount + creditCount;
  bool get isEmpty => totalCount == 0;
}
