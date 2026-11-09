// PBI-007 AC5 (found in device QA): Android shares a file under its real
// name, so the share sheet gets neutral-named copies, never the internal
// "<uuid>.pdf".
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/vault/ui/document_pages.dart';
import 'package:path/path.dart' as p;

DocumentFile file(String path, String mime) => DocumentFile(
  id: p.basenameWithoutExtension(path),
  userId: 'u',
  updatedAt: 0,
  version: 1,
  documentId: 'd',
  pageNo: 1,
  byteSize: 3,
  mime: mime,
  sha256: 'x',
  localPath: path,
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('lifeos_share_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('neutral names: Document.pdf, or Document N.jpg for several', () {
    final pdf = file('a.pdf', 'application/pdf');
    final jpg = file('b.jpg', 'image/jpeg');
    expect(neutralShareName(pdf, 0, 1), 'Document.pdf');
    expect(neutralShareName(jpg, 0, 2), 'Document 1.jpg');
    expect(neutralShareName(jpg, 1, 2), 'Document 2.jpg');
  });

  test('copies carry the neutral names and the same bytes', () async {
    final a = File(p.join(tmp.path, '01a1bec1-a308-7043.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    final b = File(p.join(tmp.path, '01a1bec1-a309-7043.jpg'))
      ..writeAsBytesSync([4, 5, 6]);
    final shareDir = Directory(p.join(tmp.path, 'share'));
    final copies = await prepareShareCopies(
      [file(a.path, 'image/jpeg'), file(b.path, 'image/jpeg')],
      shareDir,
      (f) => File(f.localPath!).readAsBytes(),
    );

    expect(copies.map(p.basename), ['Document 1.jpg', 'Document 2.jpg']);
    expect(File(copies[0]).readAsBytesSync(), [1, 2, 3]);
    expect(File(copies[1]).readAsBytesSync(), [4, 5, 6]);
    expect(a.existsSync() && b.existsSync(), isTrue, reason: 'originals kept');
    for (final c in copies) {
      expect(c, isNot(contains('01a1bec1')));
    }
  });

  test('each share starts from an empty folder', () async {
    final a = File(p.join(tmp.path, 'x.pdf'))..writeAsBytesSync([9]);
    final shareDir = Directory(p.join(tmp.path, 'share'));
    Future<Uint8List> read(DocumentFile f) => File(f.localPath!).readAsBytes();
    await prepareShareCopies(
      [file(a.path, 'image/jpeg'), file(a.path, 'image/jpeg')],
      shareDir,
      read,
    );
    await prepareShareCopies([file(a.path, 'application/pdf')], shareDir, read);
    expect(shareDir.listSync().map((e) => p.basename(e.path)), [
      'Document.pdf',
    ]);
  });
}
