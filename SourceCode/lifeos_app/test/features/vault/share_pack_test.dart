// PBI-028a: watermark burned into the pixels (AC1), originals untouched
// (AC2), bundle order and name (AC3), Urdu stamping (AC7), speed (AC8).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/vault/data/share_pack.dart';

/// A 300×420 page of one solid colour (PNG), like a scanned page.
Uint8List solidPage(int r, int g, int b) {
  final page = img.Image(width: 300, height: 420);
  img.fill(page, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(page));
}

var _n = 0;
DocumentFile file(String mime, int pageNo, String docId) => DocumentFile(
  id: 'f${_n++}',
  userId: 'u',
  updatedAt: 0,
  version: 1,
  documentId: docId,
  pageNo: pageNo,
  byteSize: 1,
  mime: mime,
  sha256: 'x',
  localPath: 'unused',
);

/// Stands in for pdfx: a "PDF" is a list of colours, one page each.
class FakeRasterizer implements PdfRasterizer {
  @override
  Stream<Uint8List> rasterize(Uint8List pdf, {int dpi = 150}) =>
      Stream.fromIterable([
        for (final c in jsonDecode(utf8.decode(pdf)) as List)
          solidPage(c[0] as int, c[1] as int, c[2] as int),
      ]);
}

/// The colour at the centre of an encoded page.
List<int> centre(Uint8List bytes) {
  final p = img.decodeImage(bytes)!;
  final px = p.getPixel(p.width ~/ 2, p.height ~/ 4);
  return [px.r.toInt(), px.g.toInt(), px.b.toInt()];
}

/// Share of pixels that differ from [original] by more than [tol].
double changed(Uint8List original, Uint8List stamped, {int tol = 24}) {
  final a = img.decodeImage(original)!;
  final b = img.decodeImage(stamped)!;
  var n = 0;
  for (var y = 0; y < a.height; y += 2) {
    for (var x = 0; x < a.width; x += 2) {
      final p = a.getPixel(x, y);
      final q = b.getPixel(x, y);
      if ((p.r - q.r).abs() > tol ||
          (p.g - q.g).abs() > tol ||
          (p.b - q.b).abs() > tol) {
        n++;
      }
    }
  }
  return n / ((a.width / 2) * (a.height / 2));
}

void main() {
  final red = solidPage(220, 40, 40);
  final green = solidPage(40, 200, 60);
  // A two-page "PDF": blue then yellow.
  final pdf2 = Uint8List.fromList(
    utf8.encode(
      jsonEncode([
        [40, 60, 220],
        [230, 210, 40],
      ]),
    ),
  );

  late Map<String, Uint8List> store;
  late SharePackBuilder builder;
  setUp(() {
    store = {};
    builder = SharePackBuilder(
      read: (f) async => store[f.id]!,
      rasterizer: FakeRasterizer(),
    );
  });

  DocumentFile put(String mime, int page, String doc, Uint8List bytes) {
    final f = file(mime, page, doc);
    store[f.id] = bytes;
    return f;
  }

  testWidgets('AC3: pages follow the chosen document order, then page order', (
    tester,
  ) async {
    final cv = [put('image/jpeg', 1, 'cv', green)];
    final degree = [
      put('application/pdf', 1, 'degree', pdf2), // blue, yellow
    ];
    final cnic = [
      put('image/jpeg', 2, 'cnic', green),
      put('image/jpeg', 1, 'cnic', red), // page 1 stored second
    ];
    final pages = (await tester.runAsync(
      () => builder.finalPages([degree, cnic, cv]),
    ))!;
    expect(pages.map(centre).toList(), [
      [40, 60, 220], // degree p1
      [230, 210, 40], // degree p2
      [220, 40, 40], // cnic p1
      [40, 200, 60], // cnic p2
      [40, 200, 60], // cv
    ]);
  });

  testWidgets('AC1: the watermark is in the pixels of every page', (
    tester,
  ) async {
    const text =
        'Shared by Ali with ABC Bank for account opening — 10 Nov 2026';
    final docs = [
      [put('image/jpeg', 1, 'a', red)],
      [put('application/pdf', 1, 'b', pdf2)],
    ];
    final plain = (await tester.runAsync(() => builder.finalPages(docs)))!;
    final stamped = (await tester.runAsync(
      () => builder.finalPages(docs, watermark: const Watermark(text: text)),
    ))!;
    expect(stamped, hasLength(3));
    for (var i = 0; i < 3; i++) {
      final share = changed(plain[i], stamped[i]);
      // Diagonal text across the page plus the footer band: clearly
      // visible, but the page stays readable.
      expect(share, greaterThan(0.05), reason: 'page ${i + 1} stamped');
      expect(share, lessThan(0.6), reason: 'page ${i + 1} still readable');
    }
    // The footer band sits at the bottom of each page.
    final bottom = img.decodeImage(stamped.first)!;
    // The band's corner, outside the (centred) footer text: test fonts draw
    // letters as solid boxes.
    final p = bottom.getPixel(1, bottom.height - 2);
    expect(p.r.toInt(), greaterThan(200), reason: 'light footer band');

    final pdf = (await tester.runAsync(
      () => builder.build(docs, watermark: const Watermark(text: text)),
    ))!;
    final raw = latin1.decode(pdf);
    expect(raw.startsWith('%PDF'), isTrue);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(raw), hasLength(3));
    // No text layer carries the watermark: it can't be removed by editing.
    expect(raw.contains('ABC Bank'), isFalse);
    expect(raw.contains('/Font'), isFalse);
  });

  testWidgets('AC2: the originals are never modified', (tester) async {
    final page = put('image/jpeg', 1, 'a', red);
    final before = Uint8List.fromList(store[page.id]!);
    await tester.runAsync(
      () => builder.build([
        [page],
      ], watermark: const Watermark(text: 'Shared with X')),
    );
    expect(store[page.id], before);
  });

  testWidgets('AC7: Urdu (RTL) text stamps without error', (tester) async {
    final page = put('image/jpeg', 1, 'a', red);
    final stamped = (await tester.runAsync(
      () => builder.finalPages(
        [
          [page],
        ],
        watermark: const Watermark(
          text: 'علی کی طرف سے اے بی سی بینک کو اکاؤنٹ کھولنے کے لیے — 10 نومبر 2026',
        ),
        direction: TextDirection.rtl,
      ),
    ))!;
    expect(changed(red, stamped.single), greaterThan(0.02));
  });

  testWidgets('AC8: a 10-page watermarked bundle builds quickly', (
    tester,
  ) async {
    final docs = [
      for (var i = 0; i < 10; i++) [put('image/jpeg', 1, 'd$i', red)],
    ];
    final progress = <int>[];
    final sw = Stopwatch()..start();
    await tester.runAsync(
      () => builder.build(
        docs,
        watermark: const Watermark(text: 'Shared with ABC Bank'),
        onPage: (done, _) => progress.add(done),
      ),
    );
    sw.stop();
    expect(progress, [for (var i = 1; i <= 10; i++) i]);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('bundle file names: the title, made safe, or the neutral name', () {
    expect(bundleFileName('Job Application Pack'), 'Job Application Pack.pdf');
    expect(bundleFileName('Visa: file/2026'), 'Visa file2026.pdf');
    expect(bundleFileName(null), 'Document.pdf');
    expect(bundleFileName('  '), 'Document.pdf');
  });
}
