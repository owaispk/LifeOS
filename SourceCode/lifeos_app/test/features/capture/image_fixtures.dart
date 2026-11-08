import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A document-like test image: white page with dark "text lines" made of
/// word-sized blocks. [seed] varies the layout so different seeds look like
/// different documents.
img.Image fakeDocument({int seed = 1, int width = 800, int height = 1000}) {
  final rnd = Random(seed);
  final page = img.Image(width: width, height: height);
  img.fill(page, color: img.ColorRgb8(250, 250, 248));
  for (var y = 60; y < height - 60; y += 28) {
    var x = 50;
    while (x < width - 80) {
      final w = 20 + rnd.nextInt(70);
      img.fillRect(
        page,
        x1: x,
        y1: y,
        x2: min(x + w, width - 50),
        y2: y + 12,
        color: img.ColorRgb8(30, 30, 35),
      );
      x += w + 10 + rnd.nextInt(12);
    }
  }
  return page;
}

img.Image blurred(img.Image source, {int radius = 8}) =>
    img.gaussianBlur(img.Image.from(source), radius: radius);

Uint8List jpeg(img.Image image) => img.encodeJpg(image, quality: 85);
