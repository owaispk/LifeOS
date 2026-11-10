// PBI-025 AC5 regression (device log 2026-11-09): "Delete everything"
// failed with FOREIGN KEY constraint 787 on `DELETE FROM categories` once
// an ATC rule pointed at a category. Every reference is filled here.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/security/crypto/vault_crypto.dart';
import 'package:lifeos_app/features/security/crypto/vault_files.dart';
import 'package:lifeos_app/features/settings/data/data_service.dart';

import '../../data/db_test_utils.dart';

void main() {
  test('deletes a fully linked data set without a foreign-key error', () async {
    final db = memoryDb();
    addTearDown(db.close);
    await openLocalData(db);
    final repos = await Repositories.open(db);

    final person = (await repos.persons.getAll()).first;
    final folder = (await repos.folders.getAll()).first;
    final category = (await repos.categories.getAll()).first;
    final doc = await repos.documents.insert(
      DocumentsCompanion.insert(
        title: 'Electricity bill',
        personId: Value(person.id),
        folderId: Value(folder.id),
      ),
    );
    await repos.documentFiles.insert(
      DocumentFilesCompanion.insert(
        documentId: doc.id,
        byteSize: 10,
        sha256: 'abc',
      ),
    );
    await repos.extractedFields.insert(
      ExtractedFieldsCompanion.insert(
        documentId: doc.id,
        field: 'amount',
        value: '430000',
      ),
    );
    // The phone's case: a bill rule with an expense category.
    final rule = await repos.atcRules.insert(
      AtcRulesCompanion.insert(
        kind: 'bill_pattern',
        name: 'Electricity',
        personId: Value(person.id),
        categoryId: Value(category.id),
      ),
    );
    final task = await repos.tasks.insert(
      TasksCompanion.insert(
        title: 'Pay electricity',
        personId: Value(person.id),
        atcRuleId: Value(rule.id),
        sourceDocumentId: Value(doc.id),
      ),
    );
    await repos.subtasks.insert(
      SubtasksCompanion.insert(taskId: task.id, title: 'Find meter no.'),
    );
    await repos.taskReminders.insert(
      TaskRemindersCompanion.insert(taskId: task.id, fireAt: 1),
    );
    final payment = await repos.payments.insert(
      PaymentsCompanion.insert(
        title: 'Electricity',
        dueDate: '2026-11-12',
        periodMonth: '2026-11-01',
        taskId: Value(task.id),
        atcRuleId: Value(rule.id),
        categoryId: Value(category.id),
        receiptDocumentId: Value(doc.id),
      ),
    );
    await repos.expenses.insert(
      ExpensesCompanion.insert(
        amountMinor: 430000,
        spentOn: '2026-11-09',
        categoryId: Value(category.id),
        paymentId: Value(payment.id),
        receiptDocumentId: Value(doc.id),
      ),
    );

    final keys = MemoryKeyStore();
    final crypto = VaultCrypto(keys);
    await DataService(repos, VaultFiles(repos, crypto), keys, null)
        .deleteAll(crypto);

    expect(await repos.tasks.getAll(), isEmpty);
    expect(await repos.atcRules.getAll(), isEmpty);
    expect(await repos.payments.getAll(), isEmpty);
    expect(await repos.documents.getAll(), isEmpty);
    // Defaults are seeded again afterwards.
    expect(await repos.categories.getAll(), isNotEmpty);
  });
}
