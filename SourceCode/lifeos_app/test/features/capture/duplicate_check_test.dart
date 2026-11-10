import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/capture/domain/duplicate_check.dart';

// Same template, next month: the account, meter, tariff and most of the
// history table are shared; the month, dates, readings and amounts change.
const november = '''
K-ELECTRIC  ELECTRICITY BILL
Account No: 0400012345678   Meter No: 66120   Tariff A-1(a)
Bill Month: NOV-26   Reading Date 02/11/2026   Issue Date 05/11/2026
Previous Reading 18231   Present Reading 18643   Units Consumed 412
Due Date: 14/11/2026
Payable Within Due Date Rs. 4,850   Payable After Due Date Rs. 5,335
History  OCT-26 3,120  SEP-26 5,410  AUG-26 6,980  JUL-26 7,215  JUN-26 6,040
''';

const december = '''
K-ELECTRIC  ELECTRICITY BILL
Account No: 0400012345678   Meter No: 66120   Tariff A-1(a)
Bill Month: DEC-26   Reading Date 02/12/2026   Issue Date 05/12/2026
Previous Reading 18643   Present Reading 18921   Units Consumed 278
Due Date: 14/12/2026
Payable Within Due Date Rs. 3,290   Payable After Due Date Rs. 3,620
History  NOV-26 4,850  OCT-26 3,120  SEP-26 5,410  AUG-26 6,980  JUL-26 7,215
''';

// The November bill scanned again: a few OCR slips, other line breaks.
const novemberAgain = '''
K-ELECTRlC ELECTRICITY BILL
Account No: 0400012345678 Meter No: 66120 Tariff A-1(a)
Bill Month: NOV-26
Reading Date 02/11/2026 Issue Date 05/11/2026
Previous Reading 18231 Present Reading 18643 Units Consumed 412
Due Date: 14/11/2026
Payable Within Due Date Rs. 4 850 Payable After Due Date Rs. 5,335
History OCT-26 3,120 SEP-26 5,41O AUG-26 6,980 JUL-26 7,215 JUN-26 6,040
''';

void main() {
  test('the same bill scanned again reads as the same text', () {
    expect(sameText(november, novemberAgain), isTrue);
  });

  test("next month's bill from the same company is not the same text", () {
    expect(sameText(november, december), isFalse);
  });

  test('a near image hash needs matching text when both were read', () {
    const a = '0f0f0f0f0f0f0f0f', b = '0f0f0f0f0f0f0f0e'; // 1 bit apart
    expect(
      isDuplicateCapture(
        newHash: a,
        oldHash: b,
        newText: december,
        oldText: november,
      ),
      isFalse,
      reason: 'same layout, different bill',
    );
    expect(
      isDuplicateCapture(
        newHash: a,
        oldHash: b,
        newText: novemberAgain,
        oldText: november,
      ),
      isTrue,
    );
  });

  test('without text, only a very close image hash counts', () {
    const a = '0f0f0f0f0f0f0f0f';
    expect(
      isDuplicateCapture(newHash: a, oldHash: a, newText: '', oldText: ''),
      isTrue,
    );
    expect(
      isDuplicateCapture(
        newHash: a,
        oldHash: '0f0f0f0f0f0f0f30', // 4 bits apart
        newText: '',
        oldText: november,
      ),
      isFalse,
    );
  });

  test('"4,850" and "4 850" are one number', () {
    expect(
      sameText('Total 4,850 due 14/11/2026 ref 778', 'Total 4 850 due 14/11/2026 ref 778'),
      isTrue,
    );
  });
}
