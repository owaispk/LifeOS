/// Maps Urdu (U+06F0–06F9) and Arabic-Indic (U+0660–0669) digits to 0–9,
/// and the Arabic decimal/thousands separators to "." and ",". Shared by
/// money parsing and OCR extraction (features spec §1.2).
String normalizeDigits(String s) {
  final out = StringBuffer();
  for (final rune in s.runes) {
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune == 0x066B) {
      out.write('.');
    } else if (rune == 0x066C) {
      out.write(',');
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}
