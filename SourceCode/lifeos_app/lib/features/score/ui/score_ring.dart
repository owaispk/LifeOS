import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/life_score.dart';

/// The Life Score ring: fills 0 → score in 600 ms on first show (UI flow
/// §1), coloured red < 40, amber 40–69, green ≥ 70. The number and label
/// always carry the meaning — never colour alone.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.size = 120,
    this.stroke = 10,
    this.showLabel = false,
  });

  final int score;
  final double size;
  final double stroke;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: context.l10n.scRingSemantics('$score', scoreLabel(score)),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score.toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              fraction: value / 100,
              color: Tokens.scoreColor(score),
              track: theme.colorScheme.surfaceContainerHighest,
              stroke: stroke,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.round()}',
                    key: const ValueKey('score-value'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.3,
                    ),
                  ),
                  if (showLabel)
                    Text(
                      scoreLabel(score),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(inner, 0, math.pi * 2, false, base..color = track);
    if (fraction <= 0) return;
    canvas.drawArc(
      inner,
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0, 1),
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// "↑3" / "↓2" / "=" vs yesterday, in words for screen readers.
class ScoreDelta extends StatelessWidget {
  const ScoreDelta({super.key, required this.delta});
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final d = delta;
    if (d == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final text = d > 0
        ? '↑$d'
        : d < 0
        ? '↓${-d}'
        : '=';
    return Semantics(
      label: d == 0
          ? context.l10n.scSameYesterday
          : d > 0
          ? context.l10n.scUpSince('${d.abs()}')
          : context.l10n.scDownSince('${d.abs()}'),
      excludeSemantics: true,
      child: Text(
        text,
        key: const ValueKey('score-delta'),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
