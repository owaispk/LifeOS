// PBI-003: blur detection (AC5) and perceptual hashing (AC7), pure.
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifeos_app/features/capture/domain/image_checks.dart';

import 'image_fixtures.dart';

void main() {
  group('blur detection', () {
    final sharp = fakeDocument();

    test('a crisp document is not blurry', () {
      expect(sharpness(sharp), greaterThan(blurThreshold * 5));
      expect(isBlurry(sharp), isFalse);
    });

    test('a light blur is still accepted (text readable)', () {
      expect(isBlurry(blurred(sharp, radius: 4)), isFalse);
    });

    test('a defocused document is blurry', () {
      final soft = blurred(sharp, radius: 12);
      expect(sharpness(soft), lessThan(blurThreshold));
      expect(isBlurry(soft), isTrue);
    });

    test('survives JPEG compression and large images', () {
      final big = fakeDocument(seed: 3, width: 2400, height: 3200);
      final decoded = img.decodeJpg(jpeg(big))!;
      expect(isBlurry(decoded), isFalse);
      expect(isBlurry(img.decodeJpg(jpeg(blurred(big, radius: 20)))!), isTrue);
    });

    test('a blank page is blurry (nothing to read)', () {
      final blank = img.Image(width: 400, height: 500);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      expect(isBlurry(blank), isTrue);
    });
  });

  group('difference hash', () {
    test('16 hex chars, identical for the same image', () {
      final a = differenceHash(fakeDocument(seed: 7));
      expect(a, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(differenceHash(fakeDocument(seed: 7)), a);
    });

    test(
      'a re-scan (resized, re-compressed, brighter) is a near duplicate',
      () {
        final original = fakeDocument(seed: 7);
        final rescan = img.adjustColor(
          img.decodeJpg(jpeg(img.copyResize(original, width: 600)))!,
          brightness: 1.08,
        );
        final d = hammingDistance(
          differenceHash(original),
          differenceHash(rescan),
        );
        expect(d, lessThanOrEqualTo(duplicateMaxDistance));
        expect(
          isNearDuplicate(differenceHash(original), differenceHash(rescan)),
          isTrue,
        );
      },
    );

    test('different documents are not duplicates', () {
      final a = differenceHash(fakeDocument(seed: 1));
      final b = differenceHash(fakeDocument(seed: 2));
      expect(hammingDistance(a, b), greaterThan(duplicateMaxDistance));
      expect(isNearDuplicate(a, b), isFalse);
    });

    test('hamming distance', () {
      expect(hammingDistance('0000000000000000', '0000000000000000'), 0);
      expect(hammingDistance('0000000000000000', 'ffffffffffffffff'), 64);
      expect(hammingDistance('000000000000000f', '0000000000000001'), 3);
    });
  });
}
