// PBI-008 widget tests: Expiring Soon (AC3), the one-time prompt, the
// ladder in the viewer, and Mark renewed → scan → old archived (AC6).
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:path/path.dart' as p;

import '../../fakes.dart';
import '../../widget_test_utils.dart';
import '../capture/image_fixtures.dart';

late CaptureFakes fakes;
late Directory tmp;
CaptureFakes makeFakes() {
  tmp = Directory.systemTemp.createTempSync('lifeos_exp_');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold an image open.
    }
  });
  fakes = CaptureFakes(Directory(p.join(tmp.path, 'vault'))..createSync());
  return fakes;
}

Future<Document> doc(
  TestApp app,
  WidgetTester tester,
  String title, {
  String type = 'passport',
  String? expiry,
  bool archived = false,
}) => app.write(
  tester,
  () => app.repos.documents.insert(
    DocumentsCompanion.insert(
      title: title,
      docType: Value(type),
      expiryDate: Value(expiry),
      archivedAt: Value(archived ? 1 : null),
    ),
  ),
);

Future<void> openViewer(WidgetTester tester, Document d) async {
  await openTab(tester, 'Vault');
  await tester.tap(find.text('Unfiled'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('doc-${d.id}')));
  await settle(tester);
  await tester.drag(
    find.byKey(const ValueKey('viewer-details')),
    const Offset(0, -700),
  );
  await tester.pumpAndSettle();
}

void main() {
  appTest('AC3: Expiring Soon is sorted and skips archived/deleted', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await doc(app, tester, 'Visa', expiry: '2026-12-30');
    await doc(app, tester, 'Passport (Ali)', expiry: '2026-11-12');
    await doc(
      app,
      tester,
      'Old passport',
      expiry: '2026-11-10',
      archived: true,
    );
    final gone = await doc(app, tester, 'Deleted', expiry: '2026-11-09');
    await app.write(tester, () => app.repos.documents.softDelete(gone.id));
    await doc(app, tester, 'CNIC', type: 'cnic', expiry: '2031-01-01');

    await openTab(tester, 'Vault');
    await tester.tap(find.byKey(const ValueKey('expiring-see-all')));
    await tester.pumpAndSettle();
    final titles = tester
        .widgetList<ListTile>(
          find.descendant(
            of: find.byKey(const ValueKey('expiring-list')),
            matching: find.byType(ListTile),
          ),
        )
        .map((t) => (t.title as Text).data)
        .toList();
    expect(titles, ['Passport (Ali)', 'Visa']);
    expect(find.text('4d left'), findsOneWidget);
  });

  appTest('the one-time "Does this document expire?" prompt', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final d = await doc(app, tester, 'Car insurance', type: 'policy');
    await openViewer(tester, d);
    expect(find.byKey(const ValueKey('expiry-prompt')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('expiry-prompt-no')));
    await settle(tester);
    expect(find.byKey(const ValueKey('expiry-prompt')), findsNothing);
    final stored = await tester.runAsync(
      () => app.repos.documents.getById(d.id),
    );
    expect(stored!.expiryPromptedAt, isNotNull);
  });

  appTest('the viewer shows the ladder and the next alert', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final d = await doc(app, tester, 'Passport (Ali)', expiry: '2027-05-27');
    await openViewer(tester, d);
    expect(
      find.text(
        'Alerts: 180 days before, 90 days before, 30 days before\n'
        'Next: Sat, 28 Nov',
      ),
      findsOneWidget,
    );
  });

  appTest('AC6: Mark renewed → scan → old one archived and linked', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final old = await doc(app, tester, 'Passport 2017', expiry: '2026-12-01');
    final page = File(p.join(tmp.path, 'new.jpg'))
      ..writeAsBytesSync(jpeg(fakeDocument(width: 200, height: 260)));
    fakes.scanner.results.add([page.path]);
    await openViewer(tester, old);

    await tester.ensureVisible(find.byKey(const ValueKey('viewer-renew')));
    await tester.tap(find.byKey(const ValueKey('viewer-renew')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('review-save')));
    await pumpUntilGone(tester, find.byKey(const ValueKey('review-reading')));
    await tester.tap(find.byKey(const ValueKey('review-save')));
    await pumpUntilFound(tester, find.text('Saved to Vault'));

    final stored = await tester.runAsync(
      () => app.repos.documents.getById(old.id),
    );
    expect(stored!.archivedAt, isNotNull);
    expect(stored.renewedById, isNotNull);
  }, capture: makeFakes);
}
