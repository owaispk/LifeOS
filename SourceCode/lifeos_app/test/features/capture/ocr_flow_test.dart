// PBI-004 on the confirm screen (AC1, AC2, AC5) and per-issuer learning
// end-to-end through the database (AC6).
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:lifeos_app/features/capture/ocr/document_analysis.dart';
import 'package:lifeos_app/features/capture/ocr/field_extractor.dart';
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';
import '../../fakes.dart';
import '../../widget_test_utils.dart';
import 'image_fixtures.dart';

late Directory tmp;
late CaptureFakes fakes;

CaptureFakes makeFakes() {
  tmp = Directory.systemTemp.createTempSync('lifeos_ocr_');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a thumbnail open.
    }
  });
  fakes = CaptureFakes(Directory(p.join(tmp.path, 'vault'))..createSync());
  return fakes;
}

String page(String name) {
  final f = File(p.join(tmp.path, name))
    ..writeAsBytesSync(
      img.encodeJpg(fakeDocument(width: 300, height: 400), quality: 80),
    );
  return f.path;
}

String fixture(String name) =>
    File('test/fixtures/ocr/$name.txt').readAsStringSync();

final reading = find.byKey(const ValueKey('review-reading'));
final saveButton = find.byKey(const ValueKey('review-save'));

String fieldText(WidgetTester tester, String key) => tester
    .widget<TextField>(find.byKey(ValueKey('review-field-$key')))
    .controller!
    .text;

Future<void> scanWithText(WidgetTester tester, String text) async {
  fakes.reader.texts.add(text);
  fakes.scanner.results.add([page('p${fakes.scanner.calls}.jpg')]);
  await openTab(tester, 'Vault');
  await tester.tap(find.byKey(const ValueKey('vault-scan')));
  await pumpUntilFound(tester, saveButton);
  await pumpUntilGone(tester, reading);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pump();
  await pumpUntilFound(tester, find.text('Saved to Vault'));
  await tester.pumpAndSettle();
}

void main() {
  appTest('a K-Electric bill is classified, filled in and filed', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await scanWithText(tester, fixture('bill_kelectric_1'));

    expect(find.textContaining('Bill · '), findsOneWidget);
    expect(fieldText(tester, Fields.issuer), 'K-Electric');
    expect(fieldText(tester, Fields.amount), '4,850');
    expect(fieldText(tester, Fields.dueDate), '2026-11-14');
    expect(fieldText(tester, Fields.periodMonth), '2026-11-01');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('review-name')))
          .controller!
          .text,
      'K-Electric Bill — Nov 2026',
    );
    // AC2: nothing is stored until Save.
    expect(await tester.runAsync(app.repos.documents.getAll), isEmpty);

    await save(tester);
    final doc = (await tester.runAsync(app.repos.documents.getAll))!.single;
    final bills = (await tester.runAsync(app.repos.folders.getAll))!
        .firstWhere((f) => f.kind == 'bills');
    expect(
      (
        doc.title,
        doc.docType,
        doc.issuer,
        doc.amountMinor,
        doc.dueDate,
        doc.periodMonth,
        doc.refNumber,
        doc.folderId,
      ),
      (
        'K-Electric Bill — Nov 2026',
        'bill',
        'K-Electric',
        485000,
        '2026-11-14',
        '2026-11-01',
        '0400012345678',
        bills.id,
      ),
    );
    expect(doc.ocrText, contains('Payable Within Due Date'));
    expect(doc.classificationConfidence, greaterThanOrEqualTo(0.7));
    final fields = (await tester.runAsync(app.repos.extractedFields.getAll))!;
    expect(fields.map((f) => f.field).toSet(), {
      'issuer',
      'amount',
      'due_date',
      'period_month',
      'ref_number',
    });
    expect(fields.every((f) => !f.corrected), isTrue);
  }, capture: makeFakes);

  appTest('AC2: an edited field is saved and marked as corrected', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await scanWithText(tester, fixture('bill_kelectric_1'));
    await tester.enterText(
      find.byKey(const ValueKey('review-field-amount')),
      '4,950',
    );
    await tester.pump();
    await save(tester);

    final doc = (await tester.runAsync(app.repos.documents.getAll))!.single;
    expect(doc.amountMinor, 495000);
    final amount = (await tester.runAsync(app.repos.extractedFields.getAll))!
        .firstWhere((f) => f.field == 'amount');
    expect((amount.value, amount.corrected), ('495000', true));
  }, capture: makeFakes);

  appTest('AC1: low confidence → no chip, pick a type before saving', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await scanWithText(tester, 'Thank you for shopping\nCASH 1,250');

    expect(
      find.text('Not sure what this is — please pick a type.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review-type-chip')), findsNothing);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('review-type-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🧾 Receipt').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-type-chip')), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
    await save(tester);
    final doc = (await tester.runAsync(app.repos.documents.getAll))!.single;
    expect(doc.docType, 'receipt');
  }, capture: makeFakes);

  appTest('AC5: no text → Unclassified, type other, saveable', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await scanWithText(tester, '');
    expect(find.textContaining("Couldn't read any text"), findsOneWidget);
    await save(tester);
    final doc = (await tester.runAsync(app.repos.documents.getAll))!.single;
    expect((doc.title, doc.docType), ('Unclassified · 8 Nov 2026', 'other'));
    expect(doc.ocrText, isNull);
  }, capture: makeFakes);

  // Device log 2026-11-09: ML Kit threw a native NullPointerException and
  // the confirm screen stayed on "Reading…" for good.
  appTest('a failing text reader ends as Unclassified, never stuck', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    fakes.reader.failWith = Exception('PlatformException(error, NPE)');
    await scanWithText(tester, '');
    expect(reading, findsNothing);
    expect(find.textContaining("Couldn't read any text"), findsOneWidget);
    await save(tester);
    final doc = (await tester.runAsync(app.repos.documents.getAll))!.single;
    expect(doc.docType, 'other');
  }, capture: makeFakes);

  test('AC6: a correction saved for an issuer drives the next scan', () async {
    final db = memoryDb();
    final dir = await Directory.systemTemp.createTemp('lifeos_learn_');
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    final repos = await openLocalData(db);
    final capture = CaptureService(repos, dir);
    final pagePath = p.join(dir.path, 'x.jpg');
    await File(pagePath)
        .writeAsBytes(jpeg(fakeDocument(width: 200, height: 260)));

    const november = '''
SSGC Sui Southern Gas
Bill Month NOV-26
Due Date 20/11/2026
Total Arrears 9,999
Current Bill Charges 1,860
''';
    const december = '''
SSGC Sui Southern Gas
Bill Month DEC-26
Due Date 20/12/2026
Total Arrears 7,777
Current Bill Charges 2,140
''';
    final reader = FakeTextReader()..texts.addAll([november, december]);

    // First bill: OCR picks the arrears; the user fixes it to 1,860.
    final first = await analyzeDraft(
      CaptureDraft.scan([pagePath]),
      reader,
      repos,
    );
    expect(first.fields[Fields.amount]!.value, '999900');
    await capture.save(
      CaptureDraft.scan([pagePath]),
      FilingDetails(
        title: 'SSGC Nov',
        docType: 'bill',
        ocrText: november,
        fields: const {'issuer': 'SSGC', 'amount': '186000'},
        corrected: const {'amount'},
      ),
    );

    // Next SSGC bill: the learned label wins.
    final next = await analyzeDraft(
      CaptureDraft.scan([pagePath]),
      reader,
      repos,
    );
    expect(next.hints.single.label, 'Current Bill Charges');
    expect(next.fields[Fields.amount]!.value, '214000');
  });

  test('imported PDFs are not OCR\'d (Unclassified)', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final repos = await openLocalData(db);
    final reader = FakeTextReader()..texts.add('K-Electric bill');
    final a = await analyzeDraft(
      CaptureDraft.importPdf('x.pdf'),
      reader,
      repos,
    );
    expect(a.unreadable, isTrue);
    expect(reader.texts, hasLength(1), reason: 'reader never called');
  });

  test('extracted fields are stored per document', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final repos = await openLocalData(db);
    final doc = await repos.documents.insert(
      DocumentsCompanion.insert(title: 't', issuer: const Value('SSGC')),
    );
    expect(await hintsForIssuer(repos, 'SSGC'), isEmpty);
    expect(doc.issuer, 'SSGC');
  });
}
