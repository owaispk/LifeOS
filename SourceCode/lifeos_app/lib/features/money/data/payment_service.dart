import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../capture/data/capture_service.dart';
import '../../tasks/data/task_service.dart';
import '../domain/money_rules.dart' show isoDate;

/// The payment has no amount yet; the user must enter one first.
class MissingAmountException implements Exception {
  const MissingAmountException();
}

/// What [PaymentService.markPaid] did, so it can be undone.
class PaidResult {
  const PaidResult({
    required this.paymentId,
    required this.expenseId,
    this.receiptDocumentId,
    this.completion,
    this.installmentBumped = false,
    this.ruleEnded = false,
    this.alreadyPaid = false,
  });

  final String paymentId;
  final String? expenseId;
  final String? receiptDocumentId;
  final CompletionResult? completion;
  final bool installmentBumped;
  final bool ruleEnded;

  /// True when the payment was already paid (double tap): nothing written.
  final bool alreadyPaid;
}

/// The completion chain (PBI-016): one action → payment paid, receipt
/// filed, expense logged, task done, installment counted.
class PaymentService {
  PaymentService(this._repos, {this.capture, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Repositories _repos;

  /// Needed only when a receipt is attached.
  final CaptureService? capture;
  final DateTime Function() _now;

  AppDatabase get _db => _repos.db;

  /// The unpaid payment linked to [taskId], if any.
  Future<Payment?> unpaidForTask(String taskId) async {
    final list = await _repos.payments.getWhere(
      (p) => p.taskId.equals(taskId) & p.status.isNotIn(['paid', 'skipped']),
    );
    return list.firstOrNull;
  }

  /// Marks [paymentId] paid. All writes happen in one transaction; if any
  /// fails, nothing is kept — not even receipt files (AC3). Paying twice is
  /// a no-op (AC4). [amountMinor] fills a payment whose amount is unknown.
  Future<PaidResult> markPaid(
    String paymentId, {
    CaptureDraft? receipt,
    int? amountMinor,
  }) async {
    String? receiptId;
    try {
      return await _db.transaction(() async {
        final p = await _repos.payments.getById(paymentId);
        if (p == null) throw StateError('Payment $paymentId not found');
        if (p.status == 'paid') {
          final existing = await _repos.expenses.getWhere(
            (e) => e.paymentId.equals(paymentId),
          );
          return PaidResult(
            paymentId: paymentId,
            expenseId: existing.firstOrNull?.id,
            receiptDocumentId: p.receiptDocumentId,
            alreadyPaid: true,
          );
        }
        final amount = p.amountMinor ?? amountMinor;
        if (amount == null || amount <= 0) {
          throw const MissingAmountException();
        }
        final rule = p.atcRuleId == null
            ? null
            : await _repos.atcRules.getById(p.atcRuleId!);
        final now = _now();

        if (receipt != null) {
          final bills = (await _repos.folders.getAll())
              .where((f) => f.kind == 'bills')
              .firstOrNull;
          final doc = await capture!.save(
            receipt,
            FilingDetails(
              title: 'Receipt — ${p.title}',
              folderId: bills?.id,
              personId: rule?.personId,
              docType: 'receipt',
              fields: {'amount': '$amount', 'issue_date': isoDate(now)},
            ),
          );
          receiptId = doc.id;
        }

        await _repos.payments.update(
          p.id,
          PaymentsCompanion(
            status: const Value('paid'),
            paidAt: Value(now.toUtc().millisecondsSinceEpoch),
            amountMinor: Value(amount),
            receiptDocumentId: Value(receiptId),
          ),
        );
        final expense = await _repos.expenses.insert(
          ExpensesCompanion.insert(
            amountMinor: amount,
            spentOn: isoDate(now),
            categoryId: Value(p.categoryId ?? rule?.categoryId),
            paymentId: Value(p.id),
            receiptDocumentId: Value(receiptId),
            note: Value(p.title),
          ),
        );

        CompletionResult? completion;
        if (p.taskId != null) {
          final task = await _repos.tasks.getById(p.taskId!);
          if (task != null && task.status == 'open') {
            completion = await TaskService(_repos, now: _now).complete(task.id);
          }
        }

        var bumped = false, ended = false;
        if (rule?.installmentTotal != null) {
          final done = (rule!.installmentDone ?? 0) + 1;
          ended = done >= rule.installmentTotal!;
          bumped = true;
          await _repos.atcRules.update(
            rule.id,
            AtcRulesCompanion(
              installmentDone: Value(done),
              status: Value(ended ? 'ended' : rule.status),
            ),
          );
        }
        return PaidResult(
          paymentId: p.id,
          expenseId: expense.id,
          receiptDocumentId: receiptId,
          completion: completion,
          installmentBumped: bumped,
          ruleEnded: ended,
        );
      });
    } on Object {
      if (receiptId != null) await capture?.discardFiles(receiptId!);
      rethrow;
    }
  }

  /// Reverses [markPaid] (5 s Undo, AC5).
  Future<void> undo(PaidResult r) async {
    if (r.alreadyPaid) return;
    await _db.transaction(() async {
      final p = await _repos.payments.getById(r.paymentId);
      if (p == null) return;
      await _repos.payments.update(
        p.id,
        const PaymentsCompanion(
          status: Value('upcoming'),
          paidAt: Value(null),
          receiptDocumentId: Value(null),
        ),
      );
      if (r.expenseId != null) await _repos.expenses.softDelete(r.expenseId!);
      if (r.receiptDocumentId != null) {
        await _repos.documents.softDelete(r.receiptDocumentId!); // → Trash
      }
      if (r.completion != null) {
        await TaskService(_repos, now: _now).undoComplete(r.completion!);
      }
      if (r.installmentBumped && p.atcRuleId != null) {
        final rule = await _repos.atcRules.getById(p.atcRuleId!);
        if (rule != null) {
          await _repos.atcRules.update(
            rule.id,
            AtcRulesCompanion(
              installmentDone: Value((rule.installmentDone ?? 1) - 1),
              status: Value(r.ruleEnded ? 'active' : rule.status),
            ),
          );
        }
      }
    });
  }
}
