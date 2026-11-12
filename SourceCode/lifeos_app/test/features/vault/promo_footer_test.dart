// PBI-038 F-03: free-tier shares get a strip under every page with a QR
// code and one line; the page itself is never covered.
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifeos_app/core/app_links.dart';
import 'package:lifeos_app/features/vault/data/share_pack.dart';

import 'share_pack_test.dart' show FakeRasterizer, file, solidPage;

const footer = PromoFooter(text: 'Shared with LifeOS', url: promoDownloadUrl);

/// Share of dark pixels in the box [x0, x1) × [y0, y1).
double darkShare(img.Image p, int x0, int y0, int x1, int y1) {
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      if (p.getPixel(x, y).r < 100) n++;
    }
  }
  return n / ((x1 - x0) * (y1 - y0));
}

/// The QR code's square in a 300 px wide page with the 64 px strip.
bool qrAtStart(img.Image p) => darkShare(p, 8, 428, 56, 476) > 0.3;
bool qrAtEnd(img.Image p) => darkShare(p, 244, 428, 292, 476) > 0.3;

void main() {
  final red = solidPage(220, 40, 40);

  testWidgets('the strip goes under the page; the page is untouched', (
    tester,
  ) async {
    final out = (await tester.runAsync(
      () => stampPromo(red, footer, TextDirection.ltr),
    ))!;
    final page = img.decodeImage(out)!;
    expect(page.width, 300);
    expect(page.height, 420 + 64, reason: 'the 64 px minimum strip');
    // The page area keeps its colour, right down to its last row.
    for (final y in [10, 210, 418]) {
      final px = page.getPixel(150, y);
      expect(px.r, greaterThan(180), reason: 'row $y still red');
      expect(px.g, lessThan(90), reason: 'row $y still red');
    }
    // QR finder pattern at the start: its dark outer ring, then white.
    expect(qrAtStart(page), isTrue, reason: 'QR in the start corner');
    expect(page.getPixel(299, 483).r, greaterThan(200), reason: 'paper');
  });

  testWidgets('in Urdu the QR code sits at the right (start) edge', (
    tester,
  ) async {
    final out = (await tester.runAsync(
      () => stampPromo(red, footer, TextDirection.rtl),
    ))!;
    final page = img.decodeImage(out)!;
    expect(qrAtEnd(page), isTrue);
    expect(qrAtStart(page), isFalse);
  });

  testWidgets('every page of a pack gets it, after the watermark', (
    tester,
  ) async {
    final store = <String, Uint8List>{};
    final builder = SharePackBuilder(
      read: (f) async => store[f.id]!,
      rasterizer: FakeRasterizer(),
    );
    final a = file('image/jpeg', 1, 'a');
    final b = file('image/jpeg', 2, 'a');
    store[a.id] = red;
    store[b.id] = solidPage(40, 200, 60);

    final pages = (await tester.runAsync(
      () => builder.finalPages(
        [
          [a, b],
        ],
        watermark: const Watermark(text: 'Shared by Ali with ABC Bank'),
        promo: footer,
      ),
    ))!;
    expect(pages, hasLength(2));
    for (final bytes in pages) {
      final p = img.decodeImage(bytes)!;
      expect(p.height, 420 + 64);
      // The watermark's light band stays at the bottom of the page itself,
      // above the footer strip — the two never overlap.
      expect(p.getPixel(1, 418).r, greaterThan(200));
      expect(qrAtStart(p), isTrue);
    }

    final plain = (await tester.runAsync(
      () => builder.finalPages([
        [a],
      ]),
    ))!;
    expect(img.decodeImage(plain.single)!.height, 420, reason: 'Premium');
  });
}
