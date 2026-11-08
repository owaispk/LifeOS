// Pure image checks for PBI-003 — blur detection and perceptual hashing.
// Runs on decoded images (package:image); no Flutter, no plugins.
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Sharpness below this means "Retake? Image looks unclear".
/// Calibrated on synthetic document pages (measured on the 512 px working
/// copy): crisp pages score ~8,600–33,000; a light blur (~5 px) ~150; blur
/// that makes text unreadable (≥ ~7 px) < 50. Re-check on real phone scans
/// during device QA (PBI-003 notes).
const blurThreshold = 100.0;

/// Near-duplicate when the 64-bit difference hashes differ in at most this
/// many bits.
const duplicateMaxDistance = 6;

/// Variance of the Laplacian (edge response) on a downscaled grey copy.
/// Sharp text and edges → high; blur → low.
double sharpness(img.Image image) {
  final small = image.width > 512 ? img.copyResize(image, width: 512) : image;
  final grey = img.grayscale(img.Image.from(small));
  final w = grey.width, h = grey.height;
  if (w < 3 || h < 3) return 0;

  final lum = Float64List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      lum[y * w + x] = grey.getPixel(x, y).r.toDouble();
    }
  }
  var sum = 0.0, sumSq = 0.0;
  var n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final lap =
          lum[i - w] + lum[i + w] + lum[i - 1] + lum[i + 1] - 4 * lum[i];
      sum += lap;
      sumSq += lap * lap;
      n++;
    }
  }
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

bool isBlurry(img.Image image, {double threshold = blurThreshold}) =>
    sharpness(image) < threshold;

/// 64-bit difference hash ("dHash") as 16 hex chars: resize to 9×8 grey,
/// one bit per horizontal neighbour comparison. Robust to scaling and small
/// brightness changes; used for duplicate detection.
String differenceHash(img.Image image) {
  final small = img.grayscale(
    img.copyResize(
      image,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    ),
  );
  var bits = BigInt.zero;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final left = small.getPixel(x, y).r;
      final right = small.getPixel(x + 1, y).r;
      bits = (bits << 1) | (left > right ? BigInt.one : BigInt.zero);
    }
  }
  return bits.toRadixString(16).padLeft(16, '0');
}

/// Number of differing bits between two hex hashes of equal length.
int hammingDistance(String a, String b) {
  var x = BigInt.parse(a, radix: 16) ^ BigInt.parse(b, radix: 16);
  var count = 0;
  while (x > BigInt.zero) {
    if (x & BigInt.one == BigInt.one) count++;
    x >>= 1;
  }
  return count;
}

bool isNearDuplicate(String a, String b) =>
    hammingDistance(a, b) <= duplicateMaxDistance;
