// PBI-004: classifier + extractors, pure Dart (AC3–AC7).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/capture/ocr/doc_classifier.dart';
import 'package:lifeos_app/features/capture/ocr/field_extractor.dart';

Map<String, dynamic> loadExpected() =>
    jsonDecode(File('test/fixtures/ocr/expected.json').readAsStringSync())
        as Map<String, dynamic>;

String fixture(String name) =>
    File('test/fixtures/ocr/$name.txt').readAsStringSync();

void main() {
  group('AC4: accuracy on the fixture set', () {
    final expected = loadExpected();

    test('≥ 20 fixtures exist', () {
      expect(expected.length, greaterThanOrEqualTo(20));
    });

    test('type ≥ 85%, amount and due date ≥ 80%', () {
      var typeHits = 0;
      var valueChecks = 0, valueHits = 0;
      final misses = <String>[];

      expected.forEach((name, raw) {
        final exp = raw as Map<String, dynamic>;
        final text = fixture(name);
        final c = classify(text);
        if (c.type == exp['type']) {
          typeHits++;
        } else {
          misses.add('$name: type ${c.type} (wanted ${exp['type']})');
        }
        final fields = extractFields(exp['type'] as String, text);
        for (final key in ['amount', 'due_date']) {
          if (!exp.containsKey(key)) continue;
          valueChecks++;
          final got = fields[key]?.value;
          if (got == exp[key].toString()) {
            valueHits++;
          } else {
            misses.add('$name: $key $got (wanted ${exp[key]})');
          }
        }
      });

      final typeAcc = typeHits / expected.length;
      final valueAcc = valueHits / valueChecks;
      // ignore: avoid_print
      print(
        'OCR accuracy: type ${(typeAcc * 100).toStringAsFixed(1)}% '
        '($typeHits/${expected.length}), amount+due '
        '${(valueAcc * 100).toStringAsFixed(1)}% ($valueHits/$valueChecks)'
        '${misses.isEmpty ? '' : '\n  misses: ${misses.join('\n  ')}'}',
      );
      expect(typeAcc, greaterThanOrEqualTo(0.85));
      expect(valueAcc, greaterThanOrEqualTo(0.80));
    });

    test('other expected fields (issuer, numbers, expiry) are extracted', () {
      var checks = 0, hits = 0;
      final misses = <String>[];
      expected.forEach((name, raw) {
        final exp = raw as Map<String, dynamic>;
        final fields = extractFields(exp['type'] as String, fixture(name));
        for (final key in exp.keys) {
          if (const {'type', 'amount', 'due_date'}.contains(key)) continue;
          checks++;
          if (fields[key]?.value == exp[key].toString()) {
            hits++;
          } else {
            misses.add(
              '$name: $key ${fields[key]?.value} (wanted ${exp[key]})',
            );
          }
        }
      });
      // ignore: avoid_print
      print(
        'Other fields: $hits/$checks'
        '${misses.isEmpty ? '' : '\n  ${misses.join('\n  ')}'}',
      );
      expect(hits / checks, greaterThanOrEqualTo(0.8));
    });
  });

  group('AC1: confidence', () {
    test('clear documents are confident; thin evidence is not', () {
      expect(classify(fixture('bill_kelectric_1')).isConfident, isTrue);
      expect(classify(fixture('passport_1')).isConfident, isTrue);
      expect(classify('Thank you').isConfident, isFalse);
      expect(classify('bill').isConfident, isFalse);
    });
  });

  test('AC5: unreadable → other, zero confidence, "Unclassified" title', () {
    final c = classify('   \n  ');
    expect((c.type, c.confidence), ('other', 0.0));
    expect(extractFields('other', ''), isEmpty);
    expect(
      autoTitle('other', const {}, DateTime(2026, 11, 8)),
      'Unclassified · 8 Nov 2026',
    );
  });

  group('AC3: dates and digits', () {
    test('day-first numeric, named months, ISO, two-digit years', () {
      expect(parseDate('Due 14/11/2026'), DateTime(2026, 11, 14));
      expect(parseDate('24-10-2026'), DateTime(2026, 10, 24));
      expect(parseDate('15.06.2029'), DateTime(2029, 6, 15));
      expect(parseDate('21-NOV-26'), DateTime(2026, 11, 21));
      expect(parseDate('09 MAR 2027'), DateTime(2027, 3, 9));
      expect(parseDate('Nov 25, 2026'), DateTime(2026, 11, 25));
      expect(parseDate('2026-11-08'), DateTime(2026, 11, 8));
      expect(parseDate('۱۸/۱۰/۲۰۲۶'), DateTime(2026, 10, 18));
      expect(parseDate('31/02/2026'), isNull, reason: 'no 31 Feb');
      expect(parseDate('no date here'), isNull);
    });

    test('billing months', () {
      expect(parseMonth('NOV-26'), DateTime(2026, 11));
      expect(parseMonth('November 2026'), DateTime(2026, 11));
      expect(parseMonth('11/2026'), DateTime(2026, 11));
      expect(parseMonth('OCT-۲۶'), DateTime(2026, 10));
    });
  });

  test('auto-titles and folders', () {
    final now = DateTime(2026, 11, 8);
    expect(
      autoTitle('bill', {
        Fields.issuer: 'K-Electric',
        Fields.periodMonth: '2026-11-01',
      }, now),
      'K-Electric Bill — Nov 2026',
    );
    expect(
      autoTitle('passport', {Fields.name: 'Ali Khan'}, now),
      'Passport — Ali Khan',
    );
    expect(
      autoTitle('fee_voucher', {Fields.studentName: 'Ali Owais'}, now),
      'Ali Owais — school fee',
    );
    expect(folderKindFor('cnic'), 'identity');
    expect(folderKindFor('bill'), 'bills');
    expect(folderKindFor('prescription'), 'medical');
    expect(folderKindFor('other'), isNull);
  });

  group('AC6: per-issuer learning', () {
    // An issuer whose bill prints the arrears first: the default rules
    // pick the wrong "Total" line.
    const first = '''
SSGC Sui Southern Gas
Bill Month NOV-26
Due Date 20/11/2026
Total Arrears 9,999
Current Bill Charges 1,860
''';
    const next = '''
SSGC Sui Southern Gas
Bill Month DEC-26
Due Date 20/12/2026
Total Arrears 7,777
Current Bill Charges 2,140
''';

    test('the correction teaches a label used next time', () {
      final before = extractFields('bill', first);
      expect(before[Fields.amount]!.value, '999900'); // wrong line

      // The user corrects the amount to Rs 1,860.
      final hints = learnHints([
        (field: Fields.amount, value: '186000', ocrText: first),
      ]);
      expect(hints.single.label, 'Current Bill Charges');

      final after = extractFields('bill', next, hints: hints);
      expect(after[Fields.amount]!.value, '214000');
      expect(after[Fields.amount]!.confidence, greaterThan(0.9));
      // Unrelated fields still come from the built-in rules.
      expect(after[Fields.dueDate]!.value, '2026-12-20');
    });

    test('no usable label → no hint', () {
      expect(
        learnHints([(field: Fields.amount, value: '186000', ocrText: '1,860')]),
        isEmpty,
      );
    });
  });

  test('AC7: only fields relevant to the type are returned', () {
    final f = extractFields('prescription', fixture('bill_kelectric_1'));
    expect(f.keys.toSet().difference({'issue_date', 'doctor'}), isEmpty);
  });

  test('robustness: typical OCR damage still extracts ≥ 80%', () {
    // The fixtures were written alongside the extractor, so they flatter it.
    // This damages them the way phone OCR does — misread letters, merged
    // lines, lost colons — and reports what survives.
    String damage(String t) => t
        .replaceAll('Date', 'Dale')
        .replaceAll('Rs.', 'R5.')
        .replaceAll(':', ' ')
        .replaceAll('Payable', 'Payab1e')
        .replaceAll(RegExp(r'\n(?=[a-z])'), ' ');
    final expected = loadExpected();
    var typeHits = 0, checks = 0, hits = 0;
    expected.forEach((name, raw) {
      final exp = raw as Map<String, dynamic>;
      final text = damage(fixture(name));
      if (classify(text).type == exp['type']) typeHits++;
      final f = extractFields(exp['type'] as String, text);
      for (final key in ['amount', 'due_date']) {
        if (!exp.containsKey(key)) continue;
        checks++;
        if (f[key]?.value == exp[key].toString()) hits++;
      }
    });
    // ignore: avoid_print
    print(
      'Noisy OCR: type $typeHits/${expected.length}, '
      'amount+due $hits/$checks',
    );
    expect(typeHits / expected.length, greaterThanOrEqualTo(0.8));
    // Guards the OCR-tolerant label matching (was 9/26 before it).
    expect(hits / checks, greaterThanOrEqualTo(0.8));
  });

  group('reference numbers (device QA finding)', () {
    String? ref(String type, String text) =>
        extractFields(type, text)[Fields.refNumber]?.value;

    test('LESCO keeps every group: "08 11111 2233445 U"', () {
      expect(ref('bill', fixture('bill_lesco')), '08 11111 2233445 U');
    });

    test('single-token references are unchanged', () {
      expect(ref('bill', fixture('bill_kelectric_1')), '0400012345678');
      expect(ref('bill', fixture('bill_ssgc')), '1122334455');
      expect(ref('bill', fixture('bill_ptcl')), '021-34567890');
      expect(ref('fee_voucher', fixture('fee_voucher_1')), '2026-11-778');
    });

    test('a following word is never swallowed; spaces normalised', () {
      expect(
        ref(
          'bill',
          'K-ELECTRIC\nELECTRICITY BILL\nAccount No: 0400012345678 Name ALI',
        ),
        '0400012345678',
      );
      expect(
        ref(
          'bill',
          'LESCO\nELECTRICITY BILL\nReference No 08   11111  2233445 U',
        ),
        '08 11111 2233445 U',
      );
    });
  });
}
