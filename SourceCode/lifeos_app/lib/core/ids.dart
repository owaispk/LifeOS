import 'dart:math';

/// Client-generated, time-ordered UUIDv7 ids (RFC 9562), created offline.
///
/// Layout: 48-bit unix-ms timestamp · version 7 · 12-bit counter ·
/// variant 10 · 62 random bits. The counter makes ids generated in the same
/// millisecond strictly increasing (RFC 9562 §6.2 method 1), and the
/// timestamp never moves backwards even if the wall clock does — so the
/// string form always sorts in creation order.
class IdGenerator {
  IdGenerator({int Function()? nowMs, Random? random})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _random = random ?? Random.secure();

  final int Function() _nowMs;
  final Random _random;

  int _lastMs = -1;
  int _counter = 0;

  static const _maxCounter = 0xFFF;

  String next() {
    var ms = _nowMs();
    if (ms <= _lastMs) {
      // Same millisecond, or the clock went backwards: stay monotonic.
      ms = _lastMs;
      _counter++;
      if (_counter > _maxCounter) {
        ms = _lastMs + 1; // borrow the next millisecond
        _counter = 0;
      }
    } else {
      // Start low and random so ids from different devices interleave less.
      _counter = _random.nextInt(0x100);
    }
    _lastMs = ms;

    final b = List<int>.filled(16, 0);
    for (var i = 0; i < 6; i++) {
      b[i] = (ms >> (8 * (5 - i))) & 0xFF;
    }
    b[6] = 0x70 | ((_counter >> 8) & 0x0F);
    b[7] = _counter & 0xFF;
    b[8] = 0x80 | _random.nextInt(0x40);
    for (var i = 9; i < 16; i++) {
      b[i] = _random.nextInt(0x100);
    }

    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// The unix-ms timestamp encoded in a UUIDv7 string.
  static int timestampOf(String id) =>
      int.parse(id.replaceAll('-', '').substring(0, 12), radix: 16);
}

/// Process-wide generator used only as the Drift client default for `id`
/// (repositories always pass their own ids).
final fallbackIds = IdGenerator();

/// Source of "now" as UTC epoch milliseconds — injectable for tests.
typedef Clock = int Function();

int systemClock() => DateTime.now().toUtc().millisecondsSinceEpoch;
