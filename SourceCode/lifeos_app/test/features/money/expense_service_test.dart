// PBI-018: ExpenseService against a real (in-memory) SQLite database.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/money/data/expense_service.dart';
import 'package:lifeos_app/features/money/domain/money_rules.dart';

import '../../data/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late Repositories repos;
  late ExpenseService service;

  setUp(() async {
    db = memoryDb();
    repos = await openLocalData(db);
    service = ExpenseService(repos);
  });
  tearDown(() => db.close());

  Future<String> categoryId(String key) async =>
      (await repos.categories.getAll())
          .firstWhere((c) => c.systemKey == key)
          .id;

  test('AC1: Rs 1,250 manual expense → 125000 in the month total', () async {
    final e = await service.add(
      amountMinor: 125000,
      spentOn: DateTime(2026, 11, 8),
      categoryId: await categoryId('utilities'),
      note: '  Electrician  ',
    );
    expect(e.spentOn, '2026-11-08');
    expect(e.note, 'Electrician');

    final s = summarize(
      await repos.expenses.getAll(),
      await repos.categories.getAll(),
      DateTime(2026, 11),
    );
    expect(s.totalMinor, 125000);
    expect(s.expenses.single.id, e.id);
  });

  test('amount must be positive; empty notes are stored as null', () async {
    expect(
      () => service.add(amountMinor: 0, spentOn: DateTime(2026, 11, 8)),
      throwsArgumentError,
    );
    final e = await service.add(
      amountMinor: 100,
      spentOn: DateTime(2026, 11, 8),
      note: '   ',
    );
    expect(e.note, isNull);
  });

  test('edit changes amount, category, date and note', () async {
    final e = await service.add(
      amountMinor: 100,
      spentOn: DateTime(2026, 11, 8),
    );
    final rent = await categoryId('rent');
    final edited = await service.edit(
      e.id,
      amountMinor: 4500000,
      spentOn: DateTime(2026, 11, 1),
      categoryId: rent,
      note: 'November rent',
    );
    expect(
      (edited.amountMinor, edited.spentOn, edited.categoryId, edited.note),
      (4500000, '2026-11-01', rent, 'November rent'),
    );
  });

  test(
    'AC5: payment-linked expenses keep their link and cannot be deleted',
    () async {
      final payment = await repos.payments.insert(
        PaymentsCompanion.insert(
          title: 'School fee',
          dueDate: '2026-11-05',
          periodMonth: '2026-11-01',
          status: const Value('paid'),
        ),
      );
      final linked = await repos.expenses.insert(
        ExpensesCompanion.insert(
          amountMinor: 1200000,
          spentOn: '2026-11-05',
          paymentId: Value(payment.id),
        ),
      );

      final edited = await service.edit(
        linked.id,
        amountMinor: 1350000,
        spentOn: DateTime(2026, 11, 6),
        categoryId: await categoryId('fees'),
        note: 'Fee went up',
      );
      expect(edited.paymentId, payment.id);
      expect(edited.amountMinor, 1350000);

      await expectLater(
        service.delete(linked.id),
        throwsA(isA<PaymentLinkedExpenseException>()),
      );
      expect(await repos.expenses.getById(linked.id), isNotNull);
    },
  );

  test('manual expenses soft-delete', () async {
    final e = await service.add(
      amountMinor: 500,
      spentOn: DateTime(2026, 11, 8),
    );
    await service.delete(e.id);
    expect(await repos.expenses.getById(e.id), isNull);
    expect(await repos.expenses.getById(e.id, includeDeleted: true), isNotNull);
  });
}
