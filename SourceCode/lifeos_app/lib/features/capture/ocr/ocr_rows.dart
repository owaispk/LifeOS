// Rebuilds printed rows from OCR text boxes (PBI-004) — pure Dart.
//
// ML Kit returns text in blocks: on a bill, the label "Due Date" and its
// value "14/11/2026" often sit in two different blocks, so its plain
// `text` puts them lines apart and the field extractor (label, then the
// rest of the line or the next line) misses the value. Putting boxes that
// share a printed row back on one line, left to right, fixes that.

/// One OCR line and where it sits on the page (pixels).
class OcrBox {
  const OcrBox(this.text, this.left, this.top, this.right, this.bottom);

  final String text;
  final double left, top, right, bottom;

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

/// Gap put between two boxes on the same row.
const rowGap = '   ';

/// The page's text with one printed row per line, top to bottom, each row
/// read left to right.
String rowsToText(List<OcrBox> boxes) {
  final rows = <_Row>[];
  final sorted = [
    for (final b in boxes)
      if (b.text.trim().isNotEmpty && b.height > 0) b,
  ]..sort((a, b) => a.centerY.compareTo(b.centerY));

  for (final box in sorted) {
    _Row? best;
    var bestDistance = double.infinity;
    for (final row in rows) {
      final d = (row.centerY - box.centerY).abs();
      // Same row when the centres are within half the smaller line height.
      final limit = 0.5 * (box.height < row.height ? box.height : row.height);
      if (d <= limit && d < bestDistance && !row.overlapsHorizontally(box)) {
        best = row;
        bestDistance = d;
      }
    }
    (best ?? (rows..add(_Row())).last).add(box);
  }

  rows.sort((a, b) => a.centerY.compareTo(b.centerY));
  return [
    for (final row in rows)
      (row.boxes..sort((a, b) => a.left.compareTo(b.left)))
          .map((b) => b.text.trim())
          .join(rowGap),
  ].join('\n');
}

class _Row {
  final boxes = <OcrBox>[];
  double _sumCenter = 0, _sumHeight = 0;

  double get centerY => _sumCenter / boxes.length;
  double get height => _sumHeight / boxes.length;

  void add(OcrBox b) {
    boxes.add(b);
    _sumCenter += b.centerY;
    _sumHeight += b.height;
  }

  /// Two lines stacked in one column overlap horizontally; they are never
  /// one row, however close they are.
  bool overlapsHorizontally(OcrBox b) =>
      boxes.any((x) => b.left < x.right && x.left < b.right);
}
