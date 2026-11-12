// PBI-038 F-04: stored pages are capped at maxPageEdge on their long side;
// pages within the limit are kept exactly as scanned.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';
import 'image_fixtures.dart';

void main() {
  late AppDatabase db;
  late Repositories repos;
  late Directory tmp;
  late CaptureService service;

  setUp(() async {
    db = memoryDb();
    repos = await openLocalData(db);
    tmp = await Directory.systemTemp.createTemp('lifeos_pagesize_');
    service = CaptureService(
      repos,
      await Directory(p.join(tmp.path, 'vault')).create(),
      now: () => DateTime(2026, 11, 8, 10),
    );
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<(img.Image, List<int>)> storedPage(img.Image page) async {
    final src = await File(p.join(tmp.path, 'page.jpg'))
        .writeAsBytes(jpeg(page));
    final doc = await service.save(
      CaptureDraft.scan([src.path]),
      const FilingDetails(title: 'Page', format: OutputFormat.jpeg),
    );
    final f = (await repos.documentFiles.getWhere(
      (x) => x.documentId.equals(doc.id),
    )).single;
    final bytes = await File(f.localPath!).readAsBytes();
    return (img.decodeJpg(bytes)!, bytes);
  }

  test('a large portrait page shrinks to the cap, keeping its shape', () async {
    final (stored, bytes) = await storedPage(
      fakeDocument(width: 3000, height: 4000),
    );
    expect((stored.width, stored.height), (1800, maxPageEdge));
    expect(bytes.take(2), [0xFF, 0xD8]);
  });

  test('a large landscape page caps its width', () async {
    final (stored, _) = await storedPage(
      fakeDocument(width: 4000, height: 3000),
    );
    expect((stored.width, stored.height), (maxPageEdge, 1800));
  });

  test('a page within the cap is kept byte for byte', () async {
    final page = fakeDocument(width: 1200, height: 1600);
    final original = jpeg(page);
    final (_, bytes) = await storedPage(page);
    expect(sha256.convert(bytes), sha256.convert(original));
  });
}
