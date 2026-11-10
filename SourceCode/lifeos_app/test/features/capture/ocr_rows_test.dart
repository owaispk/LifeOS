import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/capture/ocr/field_extractor.dart';
import 'package:lifeos_app/features/capture/ocr/ocr_rows.dart';

// A bill as ML Kit returns it: the labels column is one block and the
// values column another, so plain block order separates every label from
// its value.
const labels = [
  OcrBox('K-ELECTRIC', 20, 20, 200, 44),
  OcrBox('Account No', 20, 80, 130, 98),
  OcrBox('Bill Month', 20, 110, 120, 128),
  OcrBox('Due Date', 20, 140, 110, 158),
  OcrBox('Payable Within Due Date', 20, 170, 250, 188),
];
const values = [
  OcrBox('0400012345678', 300, 81, 450, 99),
  OcrBox('NOV-26', 300, 112, 370, 130),
  OcrBox('14/11/2026', 300, 141, 410, 159),
  OcrBox('Rs. 4,850', 300, 171, 400, 189),
];

void main() {
  test('labels and values on one printed row come back on one line', () {
    final text = rowsToText([...labels, ...values]);
    expect(text.split('\n'), [
      'K-ELECTRIC',
      'Account No${rowGap}0400012345678',
      'Bill Month${rowGap}NOV-26',
      'Due Date${rowGap}14/11/2026',
      'Payable Within Due Date${rowGap}Rs. 4,850',
    ]);
  });

  test('the bill fields are found from the rebuilt rows', () {
    final fields = extractFields('bill', rowsToText([...labels, ...values]));
    expect(fields[Fields.dueDate]?.value, '2026-11-14');
    expect(fields[Fields.amount]?.value, '485000');
    expect(fields[Fields.periodMonth]?.value, '2026-11-01');
  });

  test('stacked lines in one column stay separate rows', () {
    // Tight line spacing: centres 10 px apart, lines 18 px high.
    final text = rowsToText(const [
      OcrBox('Line one', 20, 100, 200, 118),
      OcrBox('Line two', 20, 110, 200, 128),
    ]);
    expect(text, 'Line one\nLine two');
  });

  test('empty boxes are ignored', () {
    expect(rowsToText(const [OcrBox('  ', 0, 0, 10, 10)]), '');
    expect(rowsToText(const []), '');
  });
}
