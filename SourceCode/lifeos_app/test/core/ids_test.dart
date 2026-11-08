// PBI-002 AC7: ids are generated offline and sort by creation time.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/ids.dart';

final _uuidV7 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('ids are RFC 9562 UUIDv7 strings', () {
    final ids = IdGenerator();
    for (var i = 0; i < 1000; i++) {
      expect(ids.next(), matches(_uuidV7));
    }
  });

  test('ids encode the creation time', () {
    const now = 1793145600000; // 2026-10-28T00:00:00Z
    final id = IdGenerator(nowMs: () => now).next();
    expect(IdGenerator.timestampOf(id), now);
  });

  test('ids strictly increase across milliseconds', () {
    var t = 1793145600000;
    final ids = IdGenerator(nowMs: () => t++);
    final list = List.generate(5000, (_) => ids.next());
    _expectStrictlySorted(list);
  });

  test('ids strictly increase within the same millisecond', () {
    final ids = IdGenerator(nowMs: () => 1793145600000);
    // > 4096 forces the 12-bit counter to overflow into the next ms.
    final list = List.generate(10000, (_) => ids.next());
    _expectStrictlySorted(list);
    expect(list.toSet(), hasLength(list.length));
  });

  test('ids keep increasing when the clock goes backwards', () {
    final times = [2000000000000, 1999999999000, 1999999998000];
    var i = 0;
    final ids = IdGenerator(nowMs: () => times[i++]);
    _expectStrictlySorted([ids.next(), ids.next(), ids.next()]);
  });
}

void _expectStrictlySorted(List<String> ids) {
  for (var i = 1; i < ids.length; i++) {
    expect(ids[i].compareTo(ids[i - 1]), greaterThan(0),
        reason: 'id $i (${ids[i]}) must sort after ${ids[i - 1]}');
  }
}
