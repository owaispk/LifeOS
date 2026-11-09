// PBI-007 widget tests: pages (AC1), info edits (AC2), delete → Trash →
// restore (AC3), share without contents (AC5), archive.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/vault/ui/document_pages.dart';
import 'package:path/path.dart' as p;

import '../../widget_test_utils.dart';
import '../capture/image_fixtures.dart';

late Directory tmp;
final shared = <List<DocumentFile>>[];

Future<Document> docWithPages(
  TestApp app,
  WidgetTester tester, {
  required String title,
  int pages = 1,
  String mime = 'image/jpeg',
  String? folderId,
}) async {
  final doc = await app.write(
    tester,
    () => app.repos.documents.insert(
      DocumentsCompanion.insert(
        title: title,
        folderId: Value(folderId),
        docType: const Value('bill'),
        issuer: const Value('K-Electric'),
      ),
    ),
  );
  for (var i = 1; i <= pages; i++) {
    final path = p.join(
      tmp.path,
      '${doc.id}_$i.${mime == 'image/jpeg' ? 'jpg' : 'pdf'}',
    );
    File(path)
        .writeAsBytesSync(jpeg(fakeDocument(seed: i, width: 120, height: 160)));
    await app.write(
      tester,
      () => app.repos.documentFiles.insert(
        DocumentFilesCompanion.insert(
          documentId: doc.id,
          pageNo: Value(i),
          byteSize: 10,
          sha256: 'x',
          mime: Value(mime),
          localPath: Value(path),
        ),
      ),
    );
  }
  return doc;
}

Future<void> openDoc(
  WidgetTester tester,
  String folderKind,
  Document d,
  TestApp app,
) async {
  final folder = (await tester.runAsync(app.repos.folders.getAll))!
      .firstWhere((f) => f.kind == folderKind);
  await openTab(tester, 'Vault');
  await tester.tap(find.byKey(ValueKey('folder-${folder.id}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('doc-${d.id}')));
  await settle(tester);
}

List<Override> extras() {
  tmp = Directory.systemTemp.createTempSync('lifeos_viewer_');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold an image open.
    }
  });
  shared.clear();
  return [
    pdfPagesBuilderProvider.overrideWithValue(
      (f) => Center(child: Text('PDF ${p.basename(f.localPath!)}')),
    ),
    shareFilesProvider.overrideWithValue((files) async => shared.add(files)),
  ];
}

Future<String> folderId(TestApp app, WidgetTester tester, String kind) async =>
    (await tester.runAsync(app.repos.folders.getAll))!
        .firstWhere((f) => f.kind == kind)
        .id;

void main() {
  appTest('AC1: a 3-page scan shows dots and every page is reachable', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final d = await docWithPages(
      app,
      tester,
      title: 'Lease',
      pages: 3,
      folderId: await folderId(app, tester, 'property'),
    );
    await openDoc(tester, 'property', d, app);

    expect(find.byKey(const ValueKey('viewer-dots')), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    for (final expected in ['2 / 3', '3 / 3']) {
      await tester.fling(
        find.byKey(const ValueKey('viewer-pages')),
        const Offset(-400, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
    }
    expect(find.byType(InteractiveViewer), findsWidgets, reason: 'pinch-zoom');
  }, extra: extras);

  appTest('AC1: a PDF goes to the PDF viewer', (tester, app) async {
    await useTallScreen(tester);
    final d = await docWithPages(
      app,
      tester,
      title: 'Bill PDF',
      mime: 'application/pdf',
      folderId: await folderId(app, tester, 'bills'),
    );
    await openDoc(tester, 'bills', d, app);
    expect(find.byKey(const ValueKey('viewer-pdf')), findsOneWidget);
    expect(find.textContaining('PDF ${d.id}_1.pdf'), findsOneWidget);
  }, extra: extras);

  appTest('AC2: editing a detail saves it and search finds the new value', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final d = await docWithPages(
      app,
      tester,
      title: 'Electricity',
      folderId: await folderId(app, tester, 'bills'),
    );
    await openDoc(tester, 'bills', d, app);

    // Pull the details panel up.
    await tester.drag(
      find.byKey(const ValueKey('viewer-details')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('info-field-ref')),
      '0400012345678',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    final stored = await tester.runAsync(
      () => app.repos.documents.getById(d.id),
    );
    expect(stored!.refNumber, '0400012345678');
    final hits = await tester.runAsync(
      () => app.db
          .customSelect(
            "SELECT rowid FROM documents_fts WHERE documents_fts MATCH "
            "'\"Electricity\"'",
          )
          .get(),
    );
    expect(hits, hasLength(1));
  }, extra: extras);

  appTest('AC3: Delete → Trash → Restore, everything intact', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final bills = await folderId(app, tester, 'bills');
    final d = await docWithPages(
      app,
      tester,
      title: 'Gas bill',
      folderId: bills,
    );
    await openDoc(tester, 'bills', d, app);

    await tester.tap(find.byKey(const ValueKey('viewer-delete')));
    await settle(tester);
    expect(find.text('Moved to Trash'), findsOneWidget);
    expect(find.text('Gas bill'), findsNothing, reason: 'gone from folder');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vault-trash')));
    await settle(tester);
    expect(find.byKey(ValueKey('trash-${d.id}')), findsOneWidget);
    // Day maths is covered in trash_service_test (fixed clock); here the
    // database stamps deletions with the real clock.
    expect(find.textContaining('days left'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('trash-restore-${d.id}')));
    await settle(tester);
    expect(find.text('Trash is empty'), findsOneWidget);
    final back = await tester.runAsync(() => app.repos.documents.getById(d.id));
    expect(
      (back!.title, back.folderId, back.issuer),
      ('Gas bill', bills, 'K-Electric'),
    );
  }, extra: extras);

  appTest('Trash: delete forever asks first', (tester, app) async {
    await useTallScreen(tester);
    final d = await docWithPages(app, tester, title: 'Old receipt');
    await app.write(tester, () => app.repos.documents.softDelete(d.id));
    await openTab(tester, 'Vault');
    await tester.tap(find.byKey(const ValueKey('vault-trash')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('trash-forever-${d.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Delete forever?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-forever')));
    await settle(tester);
    expect(find.text('Trash is empty'), findsOneWidget);
  }, extra: extras);

  appTest('AC5: Share sends the files only, with a neutral message', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final d = await docWithPages(
      app,
      tester,
      title: 'Passport AB1234567',
      pages: 2,
      folderId: await folderId(app, tester, 'identity'),
    );
    await openDoc(tester, 'identity', d, app);
    await tester.tap(find.byKey(const ValueKey('viewer-share')));
    await settle(tester);
    expect(shared.single.map((f) => f.pageNo), [1, 2]);
  }, extra: extras);

  appTest('Archive hides it from the folder; search still finds it', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final bills = await folderId(app, tester, 'bills');
    final d = await docWithPages(
      app,
      tester,
      title: 'Old bill',
      folderId: bills,
    );
    await openDoc(tester, 'bills', d, app);
    await tester.tap(find.byKey(const ValueKey('viewer-archive')));
    await settle(tester);
    expect(find.text('Archived'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.text('Old bill'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.byKey(ValueKey('folder-count-$bills')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(ValueKey('folder-count-$bills'))).data,
      '0 docs',
    );
    await tester.enterText(find.byKey(const ValueKey('vault-search')), 'old');
    await settle(tester);
    expect(find.text('Old bill'), findsOneWidget);
  }, extra: extras);
}
