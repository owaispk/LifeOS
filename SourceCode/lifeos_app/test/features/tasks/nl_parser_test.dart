// PBI-010 natural-language parser (AC1–AC3). Pure: no Flutter needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/tasks/domain/nl_parser.dart';

// Sunday 8 Nov 2026, 10:00.
final now = DateTime(2026, 11, 8, 10);

DateTime? due(String s, [DateTime? at]) =>
    parseTask(s, at ?? now).dueAt(at ?? now);
String title(String s) => parseTask(s, now).title;

void main() {
  test('AC1: "pay electricity bill Friday 5pm"', () {
    final p = parseTask('pay electricity bill Friday 5pm', now);
    expect(p.title, 'Pay electricity bill');
    expect(p.dueAt(now), DateTime(2026, 11, 13, 17));
    expect(p.domain, 'money');
    expect(p.hasTime, isTrue);
    expect(p.matched.keys.toSet(), {
      ParsedPart.date,
      ParsedPart.time,
      ParsedPart.domain,
    });
  });

  // AC2: at least 30 cases.
  final cases = <(String, DateTime?, String)>[
    // Relative days
    ('call mom today', DateTime(2026, 11, 8), 'Call mom'),
    ('call mom tomorrow', DateTime(2026, 11, 9), 'Call mom'),
    ('submit form day after tomorrow', DateTime(2026, 11, 10), 'Submit form'),
    ('gym in 3 days', DateTime(2026, 11, 11), 'Gym'),
    ('review in 2 weeks', DateTime(2026, 11, 22), 'Review'),
    // Weekdays (today is Sunday)
    ('meeting monday', DateTime(2026, 11, 9), 'Meeting'),
    ('meeting on wednesday', DateTime(2026, 11, 11), 'Meeting'),
    ('report sat', DateTime(2026, 11, 14), 'Report'),
    ('lunch sunday', DateTime(2026, 11, 15), 'Lunch'),
    ('next monday standup', DateTime(2026, 11, 9), 'Standup'),
    // Times
    ('dentist 5pm', DateTime(2026, 11, 8, 17), 'Dentist'),
    ('dentist 5:30 pm', DateTime(2026, 11, 8, 17, 30), 'Dentist'),
    ('dentist 17:45', DateTime(2026, 11, 8, 17, 45), 'Dentist'),
    ('call at 5', DateTime(2026, 11, 8, 17), 'Call'),
    ('call at 9', DateTime(2026, 11, 8, 9), 'Call'),
    ('walk tomorrow morning', DateTime(2026, 11, 9, 9), 'Walk'),
    ('dinner evening', DateTime(2026, 11, 8, 18), 'Dinner'),
    ('read tonight', DateTime(2026, 11, 8, 21), 'Read'),
    ('flight 12am monday', DateTime(2026, 11, 9, 0), 'Flight'),
    ('meet 12pm', DateTime(2026, 11, 8, 12), 'Meet'),
    // Day of month / month names, across month and year boundaries
    ('rent on 1st', DateTime(2026, 12, 1), 'Rent'),
    ('fee on 14th', DateTime(2026, 11, 14), 'Fee'),
    ('pay on 8th', DateTime(2026, 11, 8), 'Pay'),
    ('pay 5th', DateTime(2026, 12, 5), 'Pay'),
    ('renew passport 14 Nov', DateTime(2026, 11, 14), 'Renew passport'),
    ('tax Nov 3', DateTime(2027, 11, 3), 'Tax'),
    ('party 31 dec', DateTime(2026, 12, 31), 'Party'),
    ('trip 2 jan', DateTime(2027, 1, 2), 'Trip'),
    ('salary 31st', DateTime(2026, 11, 30), 'Salary'),
    // Roman Urdu
    ('doodh lana aaj', DateTime(2026, 11, 8), 'Doodh lana'),
    ('bill bharna kal', DateTime(2026, 11, 9), 'Bill bharna'),
    ('masjid jumma', DateTime(2026, 11, 13), 'Masjid'),
    ('ammi ko call parson shaam', DateTime(2026, 11, 10, 18), 'Ammi ko call'),
    ('dawai 9 baje', DateTime(2026, 11, 8, 9), 'Dawai'),
    // Nothing to parse (AC3)
    ('buy groceries', null, 'Buy groceries'),
    ('', null, ''),
  ];
  for (final (input, expected, expectedTitle) in cases) {
    test('"$input"', () {
      final p = parseTask(input, now);
      expect(p.dueAt(now), expected);
      expect(p.title, expectedTitle);
    });
  }

  test('relative dates cross month and year ends', () {
    final eom = DateTime(2026, 11, 30, 10); // Monday
    expect(due('x tomorrow', eom), DateTime(2026, 12, 1));
    final eoy = DateTime(2026, 12, 31, 10); // Thursday
    expect(due('x tomorrow', eoy), DateTime(2027, 1, 1));
    expect(due('x friday', eoy), DateTime(2027, 1, 1));
    expect(due('x in 3 days', eoy), DateTime(2027, 1, 3));
    expect(due('x on 2nd', eoy), DateTime(2027, 1, 2));
    expect(due('x 29 feb', DateTime(2027, 3, 1)), DateTime(2028, 2, 29));
    final leap = DateTime(2028, 2, 1);
    expect(due('x on 30th', leap), DateTime(2028, 2, 29));
  });

  test('"next Friday" from midweek is Friday of next week', () {
    final wed = DateTime(2026, 11, 11, 10);
    expect(due('x next friday', wed), DateTime(2026, 11, 20));
    expect(due('x friday', wed), DateTime(2026, 11, 13));
  });

  test('a weekday that is today: today if the time is still ahead', () {
    expect(due('x sunday 5pm'), DateTime(2026, 11, 8, 17));
    expect(due('x sunday 9am'), DateTime(2026, 11, 15, 9));
    expect(due('x sunday'), DateTime(2026, 11, 15));
  });

  test('priority words and "!" mark it high', () {
    expect(parseTask('urgent call bank', now).highPriority, isTrue);
    expect(parseTask('call bank !', now).highPriority, isTrue);
    expect(title('call bank !'), 'Call bank');
    expect(parseTask('zaroori kaam', now).highPriority, isTrue);
    expect(parseTask('call bank', now).highPriority, isFalse);
  });

  test('domain hints', () {
    expect(parseTask('pay rent', now).domain, 'money');
    expect(parseTask('doctor appointment', now).domain, 'health');
    expect(parseTask('call Ahmed', now).domain, 'people');
    expect(parseTask('renew passport', now).domain, 'vault');
    expect(parseTask('write essay', now).domain, isNull);
  });

  test('a removed chip drops just that part', () {
    final p = parseTask('pay bill friday 5pm', now);
    final noTime = p.without(ParsedPart.time);
    expect(noTime.hasTime, isFalse);
    expect(noTime.dueAt(now), DateTime(2026, 11, 13));
    final noDate = p.without(ParsedPart.date);
    expect(noDate.date, isNull);
    expect(
      noDate.dueAt(now),
      DateTime(2026, 11, 8, 17),
      reason: 'time → today',
    );
  });

  test('AC3: never throws, whatever the input', () {
    for (final s in [
      '99:99',
      '31st feb',
      'at 0',
      '!!!',
      'on the',
      '0 jan',
      'in 999 weeks',
      '\u{1F600} tomorrow 5pm',
      '  ',
      'next',
    ]) {
      expect(() => parseTask(s, now), returnsNormally, reason: s);
      expect(parseTask(s, now).title, isNotNull);
    }
  });
}
