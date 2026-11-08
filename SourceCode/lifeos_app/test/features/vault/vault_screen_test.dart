// PBI-005 widget tests: Vault Home, folder & person views, document sheet.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import '../../widget_test_utils.dart';

Future<Folder> folder(TestApp app, WidgetTester tester, String kind) async {
  final all = await tester.runAsync(app.repos.folders.getAll);
  return all!.firstWhere((f) => f.kind == kind);
}

Future<Document> addDoc(
  TestApp app,
  WidgetTester tester,
  String title, {
  String? folderId,
  String? personId,
  bool favorite = false,
  String? expiry,
}) => app.write(
  tester,
  () => app.repos.documents.insert(
    DocumentsCompanion.insert(
      title: title,
      folderId: Value(folderId),
      personId: Value(personId),
      favorite: Value(favorite),
      expiryDate: Value(expiry),
    ),
  ),
);

String countText(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey('folder-count-$key'))).data!;

void main() {
  appTest('Vault Home lists people, the 8 system folders and counts', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openTab(tester, 'Vault');
    expect(find.text('Me'), findsOneWidget);
    for (final name in [
      'Identity',
      'Education',
      'Medical',
      'Bills & Receipts',
      'Property',
      'Vehicles',
      'Insurance',
      'Work',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('0 docs'), findsNWidgets(8));
    expect(find.byKey(const ValueKey('vault-scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('folder-unfiled')), findsNothing);
  });

  appTest('AC2: counts update on save, move and delete', (tester, app) async {
    await useTallScreen(tester);
    final identity = await folder(app, tester, 'identity');
    final medical = await folder(app, tester, 'medical');
    await openTab(tester, 'Vault');

    // Save.
    final d = await addDoc(app, tester, 'Passport', folderId: identity.id);
    expect(countText(tester, identity.id), '1 doc');

    // Move (through the document sheet).
    await tester.tap(find.byKey(ValueKey('folder-${identity.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('doc-${d.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doc-folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🏥 Medical').last);
    await settle(tester);
    await tester.tapAt(const Offset(5, 5)); // close the sheet
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(countText(tester, identity.id), '0 docs');
    expect(countText(tester, medical.id), '1 doc');

    // Delete.
    await tester.tap(find.byKey(ValueKey('folder-${medical.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('doc-${d.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doc-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-doc')));
    await settle(tester);
    expect(find.text('Nothing here yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(countText(tester, medical.id), '0 docs');
  });

  appTest('AC3: a new person appears and their view shows only theirs', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openTab(tester, 'Vault');
    await tester.tap(find.byKey(const ValueKey('add-person')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('person-name')), 'Ali');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-save')));
    await settle(tester);
    expect(find.text('Ali'), findsOneWidget);

    final people = await tester.runAsync(app.repos.persons.getAll);
    final ali = people!.firstWhere((p) => p.name == 'Ali');
    final me = people.firstWhere((p) => p.relation == 'self');
    await addDoc(app, tester, 'Ali school ID', personId: ali.id);
    await addDoc(app, tester, 'My CNIC', personId: me.id);

    await tester.tap(find.byKey(ValueKey('person-${ali.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Ali school ID'), findsOneWidget);
    expect(find.text('My CNIC'), findsNothing);
  });

  appTest('AC4: system folders have no menu; deleting a custom folder '
      'moves its documents to Unfiled', (tester, app) async {
    await useTallScreen(tester);
    final bills = await folder(app, tester, 'bills');
    await openTab(tester, 'Vault');

    await tester.tap(find.byKey(ValueKey('folder-${bills.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('folder-menu')), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-folder')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('folder-name')), 'Trips');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-save')));
    await settle(tester);
    final trips = (await tester.runAsync(app.repos.folders.getAll))!
        .firstWhere((f) => f.name == 'Trips');
    await addDoc(app, tester, 'Hotel booking', folderId: trips.id);

    await tester.tap(find.byKey(ValueKey('folder-${trips.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('folder-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('folder-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm')));
    await settle(tester);

    expect(find.text('Trips'), findsNothing);
    expect(countText(tester, 'unfiled'), '1 doc');
    await tester.tap(find.byKey(const ValueKey('folder-unfiled')));
    await tester.pumpAndSettle();
    expect(find.text('Hotel booking'), findsOneWidget);
  });

  appTest('AC5: an empty folder shows an empty state with Scan', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final work = await folder(app, tester, 'work');
    await openTab(tester, 'Vault');
    await tester.tap(find.byKey(ValueKey('folder-${work.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('📸 Scan'), findsOneWidget);
  });

  appTest('AC6: a document is two taps from the bottom bar', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final identity = await folder(app, tester, 'identity');
    final d = await addDoc(app, tester, 'CNIC', folderId: identity.id);
    await tester.tap(navItem('Vault')); // bottom bar
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('folder-${identity.id}'))); // tap 1
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('doc-${d.id}'))); // tap 2
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('doc-title')), findsOneWidget);
  });

  appTest('tags, favourites first, search and the expiring strip', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final identity = await folder(app, tester, 'identity');
    await addDoc(app, tester, 'Old receipt', folderId: identity.id);
    final passport = await addDoc(
      app,
      tester,
      'Passport (Ali)',
      folderId: identity.id,
      expiry: '2026-12-06', // 28 days after testNow
    );
    await openTab(tester, 'Vault');
    expect(find.byKey(const ValueKey('expiring-strip')), findsOneWidget);
    expect(find.text('28d left'), findsOneWidget);

    // Tag + favourite through the sheet.
    await tester.tap(find.byKey(ValueKey('folder-${identity.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('doc-${passport.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('doc-add-tag')), 'travel');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.byKey(const ValueKey('tag-travel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('doc-favorite')));
    await settle(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Favourite is listed first even though it's not the oldest/newest rule.
    final firstTitle = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .first;
    expect(firstTitle, 'Passport (Ali)');

    // Search by tag from Vault Home.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vault-search')),
      'travel',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vault-search-results')), findsOneWidget);
    expect(find.text('Passport (Ali)'), findsOneWidget);
    expect(find.text('Old receipt'), findsNothing);
  });
}
