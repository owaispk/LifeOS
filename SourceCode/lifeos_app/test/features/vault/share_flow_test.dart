// PBI-028a: the share flows end to end — watermark from the viewer, Vault
// multi-select bundles, share packs following renewals (AC4), history and
// export (AC5), no plaintext left (AC2), offline/free (AC6).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/features/security/crypto/vault_crypto.dart';
import 'package:lifeos_app/features/security/crypto/vault_files.dart';
import 'package:lifeos_app/features/settings/data/data_service.dart';
import 'package:lifeos_app/features/vault/data/share_pack.dart';
import 'package:lifeos_app/features/vault/data/share_service.dart';
import 'package:lifeos_app/features/vault/share_providers.dart';
import 'package:lifeos_app/features/vault/ui/document_pages.dart';
import 'package:lifeos_app/features/vault/ui/share_flow.dart'
    show bundleVaultTitle;
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';
import '../../widget_test_utils.dart';
import '../capture/image_fixtures.dart';

late Directory tmp;
final sentPdfs = <(Uint8List, String)>[];
final sharedFiles = <List<DocumentFile>>[];

class _NoPdfRasterizer implements PdfRasterizer {
  @override
  Stream<Uint8List> rasterize(Uint8List pdf, {int dpi = 150}) =>
      Stream.error(UnsupportedError('no PDFs in these tests'));
}

List<Override> extras() {
  tmp = Directory.systemTemp.createTempSync('lifeos_share_');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a file open.
    }
  });
  sentPdfs.clear();
  sharedFiles.clear();
  return [
    pdfRasterizerProvider.overrideWithValue(_NoPdfRasterizer()),
    sendPdfProvider.overrideWithValue(
      (bytes, name) async => sentPdfs.add((bytes, name)),
    ),
    shareFilesProvider.overrideWithValue(
      (files) async => sharedFiles.add(files),
    ),
  ];
}

Future<Document> scanDoc(
  TestApp app,
  WidgetTester tester, {
  required String title,
  required String folderKind,
  String docType = 'other',
}) async {
  final folder = (await tester.runAsync(app.repos.folders.getAll))!
      .firstWhere((f) => f.kind == folderKind);
  final doc = await app.write(
    tester,
    () => app.repos.documents.insert(
      DocumentsCompanion.insert(
        title: title,
        folderId: Value(folder.id),
        docType: Value(docType),
      ),
    ),
  );
  final path = p.join(tmp.path, '${doc.id}.jpg');
  File(path).writeAsBytesSync(jpeg(fakeDocument(width: 120, height: 160)));
  await app.write(
    tester,
    () => app.repos.documentFiles.insert(
      DocumentFilesCompanion.insert(
        documentId: doc.id,
        byteSize: 10,
        sha256: 'x',
        mime: const Value('image/jpeg'),
        localPath: Value(path),
      ),
    ),
  );
  return doc;
}

Future<void> openFolder(WidgetTester tester, TestApp app, String kind) async {
  final folder = (await tester.runAsync(app.repos.folders.getAll))!
      .firstWhere((f) => f.kind == kind);
  await openTab(tester, 'Vault');
  await tester.tap(find.byKey(ValueKey('folder-${folder.id}')));
  await tester.pumpAndSettle();
}

Future<List<ShareEvent>> history(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(app.repos.shareEvents.getAll))!;

int pdfPages(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(pdf)).length;

void main() {
  group('services', () {
    test(
      'AC2: the temporary share file is gone afterwards, even on error',
      () async {
        final dir = Directory(
          p.join(
            Directory.systemTemp.createTempSync('lifeos_tmp_').path,
            'share',
          ),
        );
        addTearDown(() => dir.parent.deleteSync(recursive: true));
        String? seen;
        await shareTempFile(
          Uint8List.fromList([1, 2, 3]),
          'Document.pdf',
          dir,
          (path) async {
            seen = path;
            expect(File(path).readAsBytesSync(), [1, 2, 3]);
          },
        );
        expect(p.basename(seen!), 'Document.pdf');
        expect(dir.existsSync(), isFalse);

        await expectLater(
          shareTempFile(
            Uint8List.fromList([1]),
            'Document.pdf',
            dir,
            (_) async => throw StateError('share sheet failed'),
          ),
          throwsStateError,
        );
        expect(dir.existsSync(), isFalse);
      },
    );

    test('a bundle saved without a title gets a real name', () {
      final d = DateTime(2026, 11, 11);
      expect(bundleVaultTitle('  ', d), startsWith('Shared PDF · '));
      expect(bundleVaultTitle(null, d), endsWith('2026'));
      expect(bundleVaultTitle(' Visa file ', d), 'Visa file');
    });

    test('watermark wording: name and purpose are optional', () {
      final d = DateTime(2026, 11, 10);
      expect(
        watermarkText(
          name: 'Ali',
          recipient: 'ABC Bank',
          purpose: 'account opening',
          date: d,
        ),
        allOf(
          startsWith('Shared by Ali with ABC Bank for account opening — '),
          endsWith('2026'),
        ),
      );
      expect(
        watermarkText(name: ' ', recipient: 'ABC Bank', date: d),
        startsWith('Shared with ABC Bank — '),
      );
      // The seeded profile name is a placeholder, not a name.
      expect(
        watermarkText(name: 'Me', recipient: 'ABC Bank', date: d),
        startsWith('Shared with ABC Bank — '),
      );
    });

    test(
      'AC4 + AC5: packs follow renewals; history goes in the export',
      () async {
        final db = memoryDb();
        addTearDown(db.close);
        await openLocalData(db);
        final repos = await Repositories.open(db);
        final service = ShareService(
          repos,
          builder: SharePackBuilder(
            read: (_) async => Uint8List(0),
            rasterizer: _NoPdfRasterizer(),
          ),
          now: () => DateTime(2026, 11, 10, 9),
        );
        Future<Document> doc(String title, String type) =>
            repos.documents.insert(
              DocumentsCompanion.insert(title: title, docType: Value(type)),
            );
        final degree = await doc('BSc Degree', 'degree');
        final oldCnic = await doc('CNIC 2016', 'cnic');
        final pack = await service.saveTemplate('Job Application Pack', [
          degree.id,
          oldCnic.id,
        ]);

        // Renew the CNIC (PBI-008): the old one points at its replacement.
        final newCnic = await doc('CNIC 2026', 'cnic');
        await repos.documents.update(
          oldCnic.id,
          DocumentsCompanion(renewedById: Value(newCnic.id)),
        );
        final resolved = await service.resolve(idsOf(pack.documentIds));
        expect(resolved.map((d) => d.title), ['BSc Degree', 'CNIC 2026']);
        expect(await service.jobPackSuggestion(), [degree.id, newCnic.id]);

        await service.record(
          documentIds: [degree.id, newCnic.id],
          recipient: 'ABC Corp',
          purpose: 'job application',
          watermarked: true,
          bundleTitle: 'Job Application Pack',
        );
        expect(await service.watchShareCount(newCnic.id).first, 1);
        expect(await service.watchShareCount(oldCnic.id).first, 0);

        final result = await DataService(
          repos,
          VaultFiles(repos, VaultCrypto(MemoryKeyStore())),
          MemoryKeyStore(),
          null,
        ).export();
        final zip = ZipDecoder().decodeBytes(result.zip);
        final csv = utf8.decode(zip.findFile('data/share_events.csv')!.content);
        expect(csv, contains('ABC Corp'));
        expect(csv, contains('job application'));
        expect(
          zip.files.map((f) => f.name),
          contains('data/bundle_templates.csv'),
        );
      },
    );
  });

  appTest(
    'AC1 + AC5: viewer → Share with watermark → one stamped PDF, logged',
    (tester, app) async {
      await useTallScreen(tester);
      final d = await scanDoc(
        app,
        tester,
        title: 'My CNIC',
        folderKind: 'identity',
        docType: 'cnic',
      );
      await openFolder(tester, app, 'identity');
      await tester.tap(find.byKey(ValueKey('doc-${d.id}')));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('viewer-share')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-watermark')));
      await tester.pumpAndSettle();
      // "Shared with" is required.
      await tester.tap(find.byKey(const ValueKey('wm-share')));
      await tester.pumpAndSettle();
      expect(find.text('Enter who it\'s for'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('wm-recipient')),
        'ABC Bank',
      );
      await tester.enterText(
        find.byKey(const ValueKey('wm-purpose')),
        'account opening',
      );
      await tester.tap(find.byKey(const ValueKey('wm-share')));
      for (var i = 0; i < 100 && sentPdfs.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await settle(tester);

      expect(sentPdfs, hasLength(1));
      final (pdf, name) = sentPdfs.single;
      expect(name, 'Document.pdf', reason: 'neutral name (PBI-007)');
      expect(pdfPages(pdf), 1);
      expect(
        latin1.decode(pdf).contains('ABC Bank'),
        isFalse,
        reason: 'pixels',
      );

      final events = await history(app, tester);
      expect(events.single.recipient, 'ABC Bank');
      expect(events.single.purpose, 'account opening');
      expect(events.single.watermarked, isTrue);
      expect(idsOf(events.single.documentIds), [d.id]);

      // A plain share is logged too; Details shows the count.
      await tester.tap(find.byKey(const ValueKey('viewer-share')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-file')));
      await settle(tester);
      expect(sharedFiles, hasLength(1));
      expect(await history(app, tester), hasLength(2));
      await pumpUntilFound(tester, find.text('Shared 2 times'));
    },
    extra: extras,
  );

  appTest('AC3: long-press → select two → Share as one PDF, titled', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final degree = await scanDoc(
      app,
      tester,
      title: 'BSc Degree',
      folderKind: 'education',
      docType: 'degree',
    );
    final transcript = await scanDoc(
      app,
      tester,
      title: 'Transcript',
      folderKind: 'education',
    );
    await openFolder(tester, app, 'education');

    await tester.longPress(find.byKey(ValueKey('doc-${transcript.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('doc-${degree.id}')));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('select-share-pdf')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('bundle-list')));

    // Picked order is kept: Transcript first, then Degree.
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('bundle-doc-'),
    );
    expect(
      rows.evaluate().map((e) => (e.widget.key! as ValueKey<String>).value),
      ['bundle-doc-${transcript.id}', 'bundle-doc-${degree.id}'],
    );
    await tester.enterText(
      find.byKey(const ValueKey('bundle-title')),
      'Job Application Pack',
    );
    await tester.tap(find.byKey(const ValueKey('bundle-save-pack')));
    await settle(tester);
    final packs = (await tester.runAsync(app.repos.bundleTemplates.getAll))!;
    expect(packs.single.name, 'Job Application Pack');
    expect(idsOf(packs.single.documentIds), [transcript.id, degree.id]);

    await tester.tap(find.byKey(const ValueKey('bundle-share')));
    for (var i = 0; i < 100 && sentPdfs.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester);
    final (pdf, name) = sentPdfs.single;
    expect(name, 'Job Application Pack.pdf');
    expect(pdfPages(pdf), 2);
    final event = (await history(app, tester)).single;
    expect(event.bundleTitle, 'Job Application Pack');
    expect(event.watermarked, isFalse);
    expect(idsOf(event.documentIds), [transcript.id, degree.id]);
  }, extra: extras);

  appTest('AC4: a share pack opens with the renewed CNIC', (tester, app) async {
    await useTallScreen(tester);
    final oldCnic = await scanDoc(
      app,
      tester,
      title: 'CNIC 2016',
      folderKind: 'identity',
      docType: 'cnic',
    );
    await app.write(
      tester,
      () => app.repos.bundleTemplates.insert(
        BundleTemplatesCompanion.insert(
          name: 'Visa file',
          documentIds: Value(jsonEncode([oldCnic.id])),
        ),
      ),
    );
    final newCnic = await scanDoc(
      app,
      tester,
      title: 'CNIC 2026',
      folderKind: 'identity',
      docType: 'cnic',
    );
    await app.write(
      tester,
      () => app.repos.documents.update(
        oldCnic.id,
        DocumentsCompanion(renewedById: Value(newCnic.id)),
      ),
    );

    await openTab(tester, 'Vault');
    await tester.tap(find.byKey(const ValueKey('vault-packs')));
    await settle(tester);
    expect(find.byKey(const ValueKey('pack-job')), findsOneWidget);
    await tester.tap(find.text('Visa file'));
    await pumpUntilFound(tester, find.byKey(const ValueKey('bundle-list')));
    expect(find.byKey(ValueKey('bundle-doc-${newCnic.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('bundle-doc-${oldCnic.id}')), findsNothing);
  }, extra: extras);

  appTest('AC5: Settings → Share history lists every share', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final d = await scanDoc(
      app,
      tester,
      title: 'Passport',
      folderKind: 'identity',
    );
    await app.write(
      tester,
      () => app.repos.shareEvents.insert(
        ShareEventsCompanion.insert(
          sharedAt: testNow.millisecondsSinceEpoch,
          documentIds: jsonEncode([d.id]),
          recipient: const Value('Embassy'),
          watermarked: const Value(true),
        ),
      ),
    );
    await openTab(tester, 'More');
    await tester.tap(find.byKey(const ValueKey('more-settings')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('set-share-history')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('settings-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('set-share-history')));
    await settle(tester);
    expect(find.text('Passport'), findsOneWidget);
    expect(find.textContaining('To Embassy'), findsOneWidget);
    expect(find.textContaining('Watermarked'), findsOneWidget);
  }, extra: extras);
}
