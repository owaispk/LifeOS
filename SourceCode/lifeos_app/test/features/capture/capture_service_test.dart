// PBI-003: CaptureService — real files in a temp folder + in-memory DB.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:lifeos_app/features/capture/domain/pdf_builder.dart';
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';
import 'image_fixtures.dart';

void main() {
  late AppDatabase db;
  late Repositories repos;
  late Directory tmp;
  late Directory vault;
  late CaptureService service;

  setUp(() async {
    db = memoryDb();
    repos = await openLocalData(db);
    tmp = await Directory.systemTemp.createTemp('lifeos_capture_');
    vault = await Directory(p.join(tmp.path, 'vault')).create();
    service = CaptureService(
      repos,
      vault,
      now: () => DateTime(2026, 11, 8, 10),
    );
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<String> writePage(String name, img.Image image, {bool png = false}) =>
      File(p.join(tmp.path, name))
          .writeAsBytes(png ? img.encodePng(image) : jpeg(image))
          .then((f) => f.path);

  Future<List<DocumentFile>> filesOf(String docId) async {
    final all = await repos.documentFiles.getWhere(
      (f) => f.documentId.equals(docId),
    );
    return all..sort((a, b) => a.pageNo.compareTo(b.pageNo));
  }

  test('default title is "Scan · 8 Nov 2026"', () {
    expect(service.defaultTitle(), 'Scan · 8 Nov 2026');
  });

  test('AC1/AC2: a 2-page scan becomes one PDF document by default', () async {
    final bills = (await repos.folders.getAll()).firstWhere(
      (f) => f.kind == 'bills',
    );
    final me = (await repos.persons.getAll()).single;
    final pages = [
      await writePage('p1.jpg', fakeDocument(seed: 1)),
      await writePage('p2.png', fakeDocument(seed: 2), png: true),
    ];

    final doc = await service.save(
      CaptureDraft.scan(pages),
      FilingDetails(
        title: 'K-Electric bill',
        folderId: bills.id,
        personId: me.id,
      ),
    );
    expect(
      (doc.title, doc.source, doc.folderId, doc.personId),
      ('K-Electric bill', 'scan', bills.id, me.id),
    );

    final files = await filesOf(doc.id);
    expect(files, hasLength(1));
    final f = files.single;
    expect((f.mime, f.pageNo), ('application/pdf', 1));
    final bytes = await File(f.localPath!).readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(f.byteSize, bytes.length);
    expect(f.sha256, sha256.convert(bytes).toString());
    expect(f.phash, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(p.isWithin(vault.path, f.localPath!), isTrue);
    expect(p.basename(p.dirname(f.localPath!)), doc.id);
  });

  test('AC3: JPEG output keeps one file per page, in order', () async {
    final pages = [
      await writePage('a.jpg', fakeDocument(seed: 1)),
      await writePage('b.png', fakeDocument(seed: 2), png: true),
      await writePage('c.jpg', fakeDocument(seed: 3)),
    ];
    final doc = await service.save(
      CaptureDraft.scan(pages),
      const FilingDetails(title: 'Lease', format: OutputFormat.jpeg),
    );
    final files = await filesOf(doc.id);
    expect(files.map((f) => (f.pageNo, f.mime)), [
      (1, 'image/jpeg'),
      (2, 'image/jpeg'),
      (3, 'image/jpeg'),
    ]);
    for (final f in files) {
      final b = await File(f.localPath!).readAsBytes();
      expect(b.take(2), [0xFF, 0xD8], reason: 'PNG pages are re-encoded');
    }
    // Each page keeps its own hash; page 1 matches the source image.
    expect(files.map((f) => f.phash).toSet(), hasLength(3));
  });

  test('a JPEG with an EXIF rotation is saved upright, tag removed', () async {
    // Sensor pixels are landscape (40x20); EXIF 6 says "rotate 90° CW",
    // so the real page is portrait (20x40).
    final sideways = img.Image(width: 40, height: 20)
      ..exif.imageIfd.orientation = 6;
    final path = await File(p.join(tmp.path, 'rot.jpg'))
        .writeAsBytes(img.encodeJpg(sideways))
        .then((f) => f.path);
    final doc = await service.save(
      CaptureDraft.scan([path]),
      const FilingDetails(title: 'Rotated', format: OutputFormat.jpeg),
    );
    final f = (await filesOf(doc.id)).single;
    final bytes = await File(f.localPath!).readAsBytes();
    final ifd = img.decodeJpgExif(bytes)?.imageIfd;
    expect(ifd?.hasOrientation ?? false, isFalse);
    final stored = img.decodeJpg(bytes)!;
    expect((stored.width, stored.height), (20, 40));
  });

  test('an imported PDF is stored as-is', () async {
    final pdf = await buildPdf([jpeg(fakeDocument())]);
    final src = await File(p.join(tmp.path, 'in.pdf')).writeAsBytes(pdf);
    final doc = await service.save(
      CaptureDraft.importPdf(src.path, source: 'share_in'),
      const FilingDetails(title: 'Shared statement'),
    );
    expect(doc.source, 'share_in');
    final f = (await filesOf(doc.id)).single;
    expect(await File(f.localPath!).readAsBytes(), pdf);
    expect(f.phash, isNull);
  });

  test('a blank title falls back to the default', () async {
    final doc = await service.save(
      CaptureDraft.scan([await writePage('x.jpg', fakeDocument())]),
      const FilingDetails(title: '   '),
    );
    expect(doc.title, 'Scan · 8 Nov 2026');
  });

  group('AC7: duplicates', () {
    test('a re-scan of the same page is found', () async {
      final first = await service.save(
        CaptureDraft.scan([await writePage('o.jpg', fakeDocument(seed: 9))]),
        const FilingDetails(title: 'Electricity Bill Oct'),
      );
      final rescan = img.adjustColor(
        img.copyResize(fakeDocument(seed: 9), width: 700),
        brightness: 1.05,
      );
      final draft = CaptureDraft.scan([await writePage('r.jpg', rescan)]);
      expect((await service.findDuplicate(draft))?.id, first.id);

      final other = CaptureDraft.scan([
        await writePage('n.jpg', fakeDocument(seed: 10)),
      ]);
      expect(await service.findDuplicate(other), isNull);
    });

    test('same issuer + reference + period is a duplicate', () async {
      await service.save(
        CaptureDraft.scan([await writePage('k1.jpg', fakeDocument(seed: 1))]),
        const FilingDetails(
          title: 'K-Electric Nov',
          issuer: 'K-Electric',
          refNumber: '0400012345',
          periodMonth: '2026-11-01',
        ),
      );
      final draft = CaptureDraft.scan([
        await writePage('k2.jpg', fakeDocument(seed: 2)),
      ]);
      const same = FilingDetails(
        title: 'x',
        issuer: 'K-Electric',
        refNumber: '0400012345',
        periodMonth: '2026-11-01',
      );
      const nextMonth = FilingDetails(
        title: 'x',
        issuer: 'K-Electric',
        refNumber: '0400012345',
        periodMonth: '2026-12-01',
      );
      expect(await service.findDuplicate(draft, details: same), isNotNull);
      expect(await service.findDuplicate(draft, details: nextMonth), isNull);
    });

    test('deleted documents are not duplicates', () async {
      final d = await service.save(
        CaptureDraft.scan([await writePage('d.jpg', fakeDocument(seed: 4))]),
        const FilingDetails(title: 'Old'),
      );
      await repos.documents.softDelete(d.id);
      final draft = CaptureDraft.scan([
        await writePage('d2.jpg', fakeDocument(seed: 4)),
      ]);
      expect(await service.findDuplicate(draft), isNull);
    });
  });

  test('AC5 helper: page checks flag a blurry capture', () async {
    final sharp = await CaptureService.checkPage(
      await writePage('s.jpg', fakeDocument()),
    );
    final soft = await CaptureService.checkPage(
      await writePage('b.jpg', blurred(fakeDocument(), radius: 14)),
    );
    expect(sharp.isBlurry, isFalse);
    expect(soft.isBlurry, isTrue);
  });

  test('a failed save leaves no files and no rows', () async {
    final good = await writePage('g.jpg', fakeDocument());
    await expectLater(
      service.save(
        CaptureDraft.scan([good]),
        const FilingDetails(title: 'x', folderId: 'no-such-folder'),
      ),
      throwsA(anything),
    );
    expect(await repos.documents.getAll(), isEmpty);
    expect(vault.listSync(), isEmpty);
  });
}
