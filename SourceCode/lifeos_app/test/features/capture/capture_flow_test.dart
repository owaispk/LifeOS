// PBI-003 widget tests: the capture flow with fake scanner / picker /
// storage / share inbox, real image files and a real Vault folder.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/capture/domain/pdf_builder.dart';
import 'package:lifeos_app/features/capture/platform/capture_platform.dart';
import 'package:lifeos_app/features/security/security_providers.dart';
import 'package:path/path.dart' as p;

import '../../fakes.dart';
import '../../widget_test_utils.dart';
import 'image_fixtures.dart';

late Directory tmp;
late CaptureFakes fakes;

CaptureFakes makeFakes() {
  tmp = Directory.systemTemp.createTempSync('lifeos_flow_');
  addTearDown(() {
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a thumbnail open; the OS temp cleaner wins.
    }
  });
  fakes = CaptureFakes(Directory(p.join(tmp.path, 'vault'))..createSync());
  return fakes;
}

/// A small page image on disk (small keeps the tests quick).
String page(String name, {int seed = 1, bool blurry = false}) {
  var image = fakeDocument(seed: seed, width: 400, height: 500);
  if (blurry) image = blurred(image, radius: 10);
  final file = File(p.join(tmp.path, name))
    ..writeAsBytesSync(img.encodeJpg(image, quality: 85));
  return file.path;
}

Future<List<Document>> docs(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(app.repos.documents.getAll))!;

Future<List<DocumentFile>> files(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(app.repos.documentFiles.getAll))!;

final reviewSave = find.byKey(const ValueKey('review-save'));
final saveAll = find.byKey(const ValueKey('batch-save-all'));

Future<void> tapScanInVault(WidgetTester tester) async {
  await openTab(tester, 'Vault');
  await tester.tap(find.byKey(const ValueKey('vault-scan')));
}

/// Waits for OCR ("Reading document…") to finish, then taps Save — the
/// button stays disabled while the document is being read.
Future<void> tapSave(WidgetTester tester) async {
  await pumpUntilGone(tester, find.byKey(const ValueKey('review-reading')));
  await tester.pump();
  await tester.tap(reviewSave);
}

Future<void> saveAndWait(WidgetTester tester) async {
  await tapSave(tester);
  await tester.pump(); // spinner appears
  await pumpUntilGone(tester, find.byType(CircularProgressIndicator));
  await tester.pumpAndSettle();
}

void main() {
  appTest('AC2: scan 2 pages → Review → Save gives one PDF in the Vault', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    fakes.scanner.results.add([page('a.jpg'), page('b.jpg', seed: 2)]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, reviewSave);

    expect(find.text('2 pages'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('review-name')))
          .controller!
          .text,
      'Unclassified · 8 Nov 2026', // no OCR text in tests → AC5
    );
    await tester.enterText(
      find.byKey(const ValueKey('review-name')),
      'K-Electric bill',
    );
    await saveAndWait(tester);

    final d = (await docs(app, tester)).single;
    expect((d.title, d.source), ('K-Electric bill', 'scan'));
    final f = (await files(app, tester)).single;
    expect(f.mime, 'application/pdf');
    expect(File(f.localPath!).existsSync(), isTrue);
    // Back in the Vault, filed under Unfiled.
    expect(find.byKey(const ValueKey('vault-home')), findsOneWidget);
    expect(find.text('Unfiled'), findsOneWidget);
  }, capture: makeFakes);

  appTest('AC3: JPEG output', (tester, app) async {
    await useTallScreen(tester);
    fakes.scanner.results.add([page('a.jpg'), page('b.jpg', seed: 2)]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, reviewSave);
    await tester.tap(find.text('JPEG'));
    await tester.pump();
    await saveAndWait(tester);
    expect((await files(app, tester)).map((f) => f.mime), [
      'image/jpeg',
      'image/jpeg',
    ]);
  }, capture: makeFakes);

  appTest('AC5: a blurry page asks "Retake?"; Retake re-opens the scanner', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    fakes.scanner.results
      ..add([page('soft.jpg', blurry: true)])
      ..add([page('sharp.jpg')]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, find.byKey(const ValueKey('dialog-blurry')));
    expect(
      find.text('Image looks unclear — text may be hard to read later.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('blurry-yes'))); // Retake
    await pumpUntilFound(tester, reviewSave);
    expect(fakes.scanner.calls, 2);
    expect(find.text('1 page'), findsOneWidget);
  }, capture: makeFakes);

  appTest('AC5: "Keep anyway" files the blurry scan', (tester, app) async {
    await useTallScreen(tester);
    fakes.scanner.results.add([page('soft.jpg', blurry: true)]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, find.byKey(const ValueKey('dialog-blurry')));
    await tester.tap(find.byKey(const ValueKey('blurry-no')));
    await pumpUntilFound(tester, reviewSave);
    expect(fakes.scanner.calls, 1);
  }, capture: makeFakes);

  appTest('AC6: low storage warns before scanning', (tester, app) async {
    await useTallScreen(tester);
    fakes.storage.mb = 42;
    fakes.scanner.results.add([page('a.jpg')]);
    await tapScanInVault(tester);
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('dialog-low-storage')),
    );
    expect(find.textContaining('Only 42 MB free'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('low-storage-no')));
    await tester.pumpAndSettle();
    expect(fakes.scanner.calls, 0, reason: 'cancel never opens the scanner');

    await tester.tap(find.byKey(const ValueKey('vault-scan')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('dialog-low-storage')),
    );
    await tester.tap(find.byKey(const ValueKey('low-storage-yes')));
    await pumpUntilFound(tester, reviewSave);
    expect(fakes.scanner.calls, 1);
  }, capture: makeFakes);

  appTest('AC7: re-scanning the same page asks "Keep both?"', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    fakes.scanner.results
      ..add([page('first.jpg', seed: 5)])
      ..add([page('again.jpg', seed: 5)]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, reviewSave);
    await tester.enterText(
      find.byKey(const ValueKey('review-name')),
      'Electricity Bill Oct',
    );
    await saveAndWait(tester);

    await tester.tap(find.byKey(const ValueKey('vault-scan')));
    await pumpUntilFound(tester, reviewSave);
    await tapSave(tester);
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('dialog-duplicate')),
    );
    // The dialog names the old document and when it was saved.
    expect(
      find.textContaining(
        "Looks like a duplicate of 'Electricity Bill Oct', saved ",
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('duplicate-discard')));
    await pumpUntilFound(tester, find.text('Duplicate discarded'));
    expect(await docs(app, tester), hasLength(1));
  }, capture: makeFakes);

  appTest('batch: scan another shows both, newest on top; Save all', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    fakes.scanner.results
      ..add([page('one.jpg', seed: 1)])
      ..add([page('two.jpg', seed: 2)]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, reviewSave);

    await tester.tap(find.byKey(const ValueKey('review-scan-another')));
    await pumpUntilFound(tester, find.text('File 2 documents'));
    await pumpUntilFound(tester, find.text('Save 2 ready documents'));
    // The new scan is the first card and marked New.
    final cards = find.byWidgetPredicate(
      (w) => w is Card && '${w.key}'.contains('batch-card-'),
    );
    expect(cards, findsNWidgets(2));
    expect(tester.widget<Card>(cards.first).key, const ValueKey('batch-card-1'));
    expect(
      find.descendant(of: cards.first, matching: find.text('New')),
      findsOneWidget,
    );

    await tester.tap(saveAll);
    await pumpUntilFound(tester, find.text('2 documents saved to Vault'));
    await tester.pumpAndSettle();
    expect(await docs(app, tester), hasLength(2));
    expect(find.byKey(const ValueKey('vault-home')), findsOneWidget);
  }, capture: makeFakes);

  appTest('batch: an edit made in one document survives going back', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    fakes.scanner.results
      ..add([page('one.jpg', seed: 1)])
      ..add([page('two.jpg', seed: 2)]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, reviewSave);
    await tester.tap(find.byKey(const ValueKey('review-scan-another')));
    await pumpUntilFound(tester, find.text('Save 2 ready documents'));

    await tester.tap(find.byKey(const ValueKey('batch-card-0')));
    await pumpUntilFound(tester, reviewSave);
    await tester.enterText(
      find.byKey(const ValueKey('review-name')),
      'Water bill',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-back-to-list')));
    await tester.pumpAndSettle();
    expect(find.text('Water bill'), findsOneWidget, reason: 'card title');

    await tester.tap(saveAll);
    await pumpUntilFound(tester, find.text('2 documents saved to Vault'));
    await tester.pumpAndSettle();
    expect(
      (await docs(app, tester)).map((d) => d.title),
      contains('Water bill'),
    );
  }, capture: makeFakes);

  appTest('batch: Save all holds back a possible duplicate', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    fakes.scanner.results
      ..add([page('old.jpg', seed: 5)])
      ..add([page('again.jpg', seed: 5)])
      ..add([page('other.jpg', seed: 7)]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, reviewSave);
    await tester.enterText(
      find.byKey(const ValueKey('review-name')),
      'Electricity Bill Oct',
    );
    await saveAndWait(tester);

    await tester.tap(find.byKey(const ValueKey('vault-scan')));
    await pumpUntilFound(tester, reviewSave);
    await tester.tap(find.byKey(const ValueKey('review-scan-another')));
    await pumpUntilFound(tester, find.text('Save 2 ready documents'));
    await tester.tap(saveAll);
    await pumpUntilFound(
      tester,
      find.text('1 document saved to Vault · 1 needs a check'),
    );
    await tester.pumpAndSettle();
    // The look-alike stays, flagged; nothing was thrown away.
    expect(
      find.text("May be a duplicate of 'Electricity Bill Oct'"),
      findsOneWidget,
    );
    expect(await docs(app, tester), hasLength(2));
  }, capture: makeFakes);

  appTest('discarding can be undone', (tester, app) async {
    await useTallScreen(tester);
    fakes.scanner.results.add([page('a.jpg')]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, reviewSave);
    await tester.tap(find.byKey(const ValueKey('review-discard')));
    await pumpUntilFound(tester, find.text('Discarded'));
    await tester.pumpAndSettle();
    expect(reviewSave, findsNothing, reason: 'the screen closed');

    await tester.tap(find.byKey(const ValueKey('discard-undo')));
    await pumpUntilFound(tester, reviewSave);
    await saveAndWait(tester);
    expect(await docs(app, tester), hasLength(1));
  }, capture: makeFakes);

  appTest('a blurry page in a longer scan can be removed alone', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    fakes.scanner.results.add([
      page('p1.jpg'),
      page('p2.jpg', seed: 2, blurry: true),
      page('p3.jpg', seed: 3),
    ]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, find.byKey(const ValueKey('dialog-blurry')));
    expect(
      find.text('Page 2 looks unclear — text may be hard to read later.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('blurry-drop')));
    await pumpUntilFound(tester, reviewSave);
    expect(find.text('2 pages'), findsOneWidget);
    expect(fakes.scanner.calls, 1);
  }, capture: makeFakes);

  appTest('tapping a page opens it full screen', (tester, app) async {
    await useTallScreen(tester);
    fakes.scanner.results.add([page('a.jpg'), page('b.jpg', seed: 2)]);
    await tapScanInVault(tester);
    await pumpUntilFound(tester, reviewSave);
    await tester.tap(find.byKey(const ValueKey('review-page-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-viewer')), findsOneWidget);
    expect(find.text('Page 2 of 2'), findsOneWidget);
  }, capture: makeFakes);

  appTest('cancelling the scanner changes nothing', (tester, app) async {
    await useTallScreen(tester);
    await tapScanInVault(tester);
    await tester.pumpAndSettle();
    expect(fakes.scanner.calls, 1);
    expect(reviewSave, findsNothing);
  }, capture: makeFakes);

  appTest('scanning from a folder files it there', (tester, app) async {
    await useTallScreen(tester);
    final medical = (await tester.runAsync(app.repos.folders.getAll))!
        .firstWhere((f) => f.kind == 'medical');
    fakes.scanner.results.add([page('rx.jpg')]);
    await openTab(tester, 'Vault');
    await tester.tap(find.byKey(ValueKey('folder-${medical.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('📸 Scan'));
    await pumpUntilFound(tester, reviewSave);
    await saveAndWait(tester);
    expect((await docs(app, tester)).single.folderId, medical.id);
  }, capture: makeFakes);

  appTest('AC8: a PDF shared from another app opens the confirm step', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final pdf = await tester.runAsync(
      () => buildPdf([img.encodeJpg(fakeDocument(width: 300, height: 400))]),
    );
    final shared = File(p.join(tmp.path, 'statement.pdf'))
      ..writeAsBytesSync(pdf!);

    fakes.inbox.controller.add([
      IncomingFile(shared.path, mime: 'application/pdf'),
    ]);
    await pumpUntilFound(tester, reviewSave);
    expect(find.text('1 page'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-format')), findsNothing);
    expect(fakes.inbox.resets, 1);

    await saveAndWait(tester);
    final d = (await docs(app, tester)).single;
    expect(d.source, 'share_in');
    // Stored encrypted (PBI-024); decrypting gives the shared PDF back.
    final stored = (await files(app, tester)).single;
    expect(File(stored.localPath!).readAsBytesSync(), isNot(pdf));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final plain = await tester.runAsync(
      () => container.read(vaultFilesProvider).read(stored),
    );
    expect(plain, pdf);
  }, capture: makeFakes);

  appTest('import from files: images become one doc, each PDF its own', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final pdf = await tester.runAsync(
      () => buildPdf([img.encodeJpg(fakeDocument(width: 300, height: 400))]),
    );
    final pdfFile = File(p.join(tmp.path, 'deed.pdf'))..writeAsBytesSync(pdf!);
    fakes.importer.next = [
      IncomingFile(page('photo1.jpg')),
      IncomingFile(pdfFile.path),
      IncomingFile(page('photo2.jpg', seed: 3)),
    ];
    await openTab(tester, 'Vault');
    await tester.tap(find.byKey(const ValueKey('vault-import')));
    await pumpUntilFound(tester, find.text('File 2 documents'));
    // The PDF is one document, both images another.
    expect(find.textContaining('2 pages'), findsOneWidget);
    expect(find.textContaining('1 page'), findsOneWidget);
    await pumpUntilFound(tester, find.text('Save 2 ready documents'));
    await tester.tap(saveAll);
    await pumpUntilFound(tester, find.text('2 documents saved to Vault'));
    await tester.pumpAndSettle();
    final all = await docs(app, tester);
    expect(all.map((d) => d.source), ['import', 'import']);
    expect(await files(app, tester), hasLength(2));
  }, capture: makeFakes);
}
