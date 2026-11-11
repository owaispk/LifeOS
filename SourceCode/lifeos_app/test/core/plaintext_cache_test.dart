// PBI-024 / PBI-028a AC2: decrypted copies don't stay on disk.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/plaintext_cache.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory cache;
  setUp(() => cache = Directory.systemTemp.createTempSync('lifeos_cache_'));
  tearDown(() => cache.deleteSync(recursive: true));

  File put(String rel) =>
      File(p.join(cache.path, rel))
        ..createSync(recursive: true)
        ..writeAsStringSync('plain');

  test('the start-up sweep removes plaintext and keeps the rest', () async {
    put('share_plus/Job Application Pack.pdf');
    put('share/Document.pdf');
    put('file_picker/123/cnic.jpg');
    put('3a8161bf83034d988be585f598f94d71.pdf'); // pdfx openData leftover
    final keep = put('data/flutter_engine.bin');
    final keepDir = put('mlkit_docscan_ui_client/x.json');

    expect(await sweepPlaintextCache(cache), 4);
    final left = cache
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => p.relative(f.path, from: cache.path))
        .toSet();
    expect(left, {
      p.relative(keep.path, from: cache.path),
      p.relative(keepDir.path, from: cache.path),
    });
  });

  test('share_plus copies go once the sheet closes', () async {
    put('share_plus/Document.pdf');
    await clearShareSheetCopies(cache);
    expect(Directory(p.join(cache.path, 'share_plus')).existsSync(), isFalse);
  });

  test('a temporary file exists only while it is used, even on error', () async {
    String? seen;
    final n = await withTempFile(cache, Uint8List.fromList([1, 2]), '.pdf', (
      path,
    ) async {
      seen = path;
      expect(File(path).readAsBytesSync(), [1, 2]);
      return 7;
    });
    expect(n, 7);
    expect(File(seen!).existsSync(), isFalse);

    await expectLater(
      withTempFile(cache, Uint8List(1), '.pdf', (path) async {
        seen = path;
        throw StateError('render failed');
      }),
      throwsStateError,
    );
    expect(File(seen!).existsSync(), isFalse);
  });
}
