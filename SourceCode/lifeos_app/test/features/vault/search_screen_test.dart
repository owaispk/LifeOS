// PBI-006 widget tests: search-as-you-type, snippets, filters, clear (AC6).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import '../../widget_test_utils.dart';

Future<Document> doc(
  TestApp app,
  WidgetTester tester,
  String title, {
  String? ocr,
  String type = 'other',
  String? expiry,
}) => app.write(
  tester,
  () => app.repos.documents.insert(
    DocumentsCompanion.insert(
      title: title,
      ocrText: Value(ocr),
      docType: Value(type),
      expiryDate: Value(expiry),
    ),
  ),
);

final results = find.byKey(const ValueKey('vault-search-results'));

/// Taps a filter chip, scrolling the sideways chip row to it first.
Future<void> tapFilter(WidgetTester tester, String key) async {
  final chip = find.byKey(ValueKey(key));
  // Build it (lazy sideways list), then bring it fully on screen.
  await tester.scrollUntilVisible(
    chip,
    80,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('vault-filters')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
}

final home = find.byKey(const ValueKey('vault-home'));

void main() {
  appTest('typing searches inside the document text and shows a snippet', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final bill = await doc(
      app,
      tester,
      'Scan · 8 Nov 2026',
      ocr: 'K-Electric bill. Payable within due date Rs. 4,850',
    );
    await doc(app, tester, 'Passport (Ali)', type: 'passport');
    await openTab(tester, 'Vault');

    await tester.enterText(find.byKey(const ValueKey('vault-search')), 'payab');
    await settle(tester);
    expect(results, findsOneWidget);
    expect(find.text('Scan · 8 Nov 2026'), findsOneWidget);
    expect(find.text('Passport (Ali)'), findsNothing);
    expect(find.byKey(ValueKey('snippet-${bill.id}')), findsOneWidget);
  });

  appTest('filters work alone and combined; Clear returns to Vault Home', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await doc(
      app,
      tester,
      'Passport (Ali)',
      type: 'passport',
      expiry: '2026-12-06',
    );
    await doc(
      app,
      tester,
      'Old passport',
      type: 'passport',
      expiry: '2031-01-01',
    );
    await doc(app, tester, 'CNIC', type: 'cnic');
    await openTab(tester, 'Vault');
    expect(home, findsOneWidget);

    // Type filter alone.
    await tester.tap(find.byKey(const ValueKey('filter-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🛂 Passport').last);
    await settle(tester);
    expect(results, findsOneWidget);
    expect(find.text('Passport (Ali)'), findsOneWidget);
    expect(find.text('Old passport'), findsOneWidget);
    expect(find.text('CNIC'), findsNothing);

    // + Expiring soon.
    await tapFilter(tester, 'filter-expiring');
    await settle(tester);
    expect(find.text('Passport (Ali)'), findsOneWidget);
    expect(find.text('Old passport'), findsNothing);

    // + a query that matches nothing among them.
    await tester.enterText(find.byKey(const ValueKey('vault-search')), 'cnic');
    await settle(tester);
    expect(find.text('No matches'), findsOneWidget);

    // AC6: Clear → back to Vault Home, query empty.
    await tapFilter(tester, 'filter-clear');
    await settle(tester);
    expect(home, findsOneWidget);
    expect(results, findsNothing);
    expect(
      tester
          .widget<SearchBar>(find.byKey(const ValueKey('vault-search')))
          .controller!
          .text,
      isEmpty,
    );
  });

  appTest('results update after an edit (index triggers)', (tester, app) async {
    await useTallScreen(tester);
    final d = await doc(app, tester, 'Untitled scan');
    await openTab(tester, 'Vault');
    await tester.enterText(find.byKey(const ValueKey('vault-search')), 'lease');
    await settle(tester);
    expect(find.text('No matches'), findsOneWidget);

    await app.write(
      tester,
      () => app.repos.documents.update(
        d.id,
        const DocumentsCompanion(title: Value('Lease agreement')),
      ),
    );
    await settle(tester);
    expect(find.text('Lease agreement'), findsOneWidget);
  });
}
