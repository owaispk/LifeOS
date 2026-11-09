import 'package:flutter/material.dart';

import '../../../core/l10n.dart';

/// 7-day score sparkline (PBI-020). One series, so no legend: the heading
/// names it. A 2 px line on a fixed 0–100 scale with a recessive baseline,
/// gaps for days without a snapshot, an 8 px marker on today and a single
/// direct label (today's value). The values are also read out as text.
class ScoreSparkline extends StatelessWidget {
  const ScoreSparkline({
    super.key,
    required this.values,
    required this.dayLabels,
  });

  /// Oldest first; null = no snapshot that day.
  final List<int?> values;

  /// One short label per value ("M", "T", …).
  final List<String> dayLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final known = [
      for (var i = 0; i < values.length; i++)
        if (values[i] != null) '${dayLabels[i]} ${values[i]}',
    ];
    return Semantics(
      label: context.l10n.scSparkSemantics(known.join(', ')),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 64,
            child: CustomPaint(
              painter: _SparkPainter(
                values: values,
                line: theme.colorScheme.primary,
                axis: theme.colorScheme.outlineVariant,
                surface: theme.colorScheme.surface,
                label: theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final l in dayLabels)
                Expanded(
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.line,
    required this.axis,
    required this.surface,
    required this.label,
  });

  final List<int?> values;
  final Color line;
  final Color axis;
  final Color surface;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 14.0; // room for the direct label
    final h = size.height - top;
    final slot = size.width / values.length;
    Offset at(int i, int v) =>
        Offset(slot * i + slot / 2, top + h - h * (v.clamp(0, 100) / 100));

    // Recessive baseline at 0.
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );

    final stroke = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path? path;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        if (path != null) canvas.drawPath(path, stroke);
        path = null;
        continue;
      }
      final p = at(i, v);
      if (path == null) {
        path = Path()..moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (path != null) canvas.drawPath(path, stroke);

    // Lone days (no neighbours) still show as a dot.
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final prev = i > 0 ? values[i - 1] : null;
      final next = i < values.length - 1 ? values[i + 1] : null;
      if (prev == null && next == null) {
        canvas.drawCircle(at(i, v), 2.5, Paint()..color = line);
      }
    }

    // Today: 8 px marker with a 2 px surface ring + its value.
    final last = values.isEmpty ? null : values.last;
    if (last != null) {
      final p = at(values.length - 1, last);
      canvas
        ..drawCircle(p, 6, Paint()..color = surface)
        ..drawCircle(p, 4, Paint()..color = line);
      final tp = TextPainter(
        text: TextSpan(text: '$last', style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (p.dx - tp.width / 2).clamp(0, size.width - tp.width),
          (p.dy - 8 - tp.height).clamp(0, size.height),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.line != line || old.axis != axis;
}
