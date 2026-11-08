import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../domain/overload.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// What the user chose in the Overload Shield dialog.
sealed class OverloadChoice {
  const OverloadChoice();
}

class AddAnyway extends OverloadChoice {
  const AddAnyway();
}

class MoveTo extends OverloadChoice {
  const MoveTo(this.day);
  final DateTime day;
}

/// 2.5 Overload Shield dialog. Returns null if dismissed (back to editing).
Future<OverloadChoice?> showOverloadDialog(
  BuildContext context,
  OverloadCheck check,
) {
  return showDialog<OverloadChoice>(
    context: context,
    builder: (context) => OverloadDialog(check: check),
  );
}

class OverloadDialog extends StatelessWidget {
  const OverloadDialog({super.key, required this.check});

  final OverloadCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayName = _weekdayNames[check.day.weekday - 1];
    final suggested = check.suggested;

    return AlertDialog(
      key: const ValueKey('overload-dialog'),
      title: Text(
        '$dayName is already full '
        '(${formatHours(check.loadWithTaskMin)} of '
        '${formatHours(check.capacityMin)})',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggested == null
                ? 'No lighter day in the next two weeks — pick a day, or add '
                      'it anyway.'
                : '${formatDay(suggested)} has room.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Tokens.spaceM),
          WeekLoadChart(week: check.week, highlight: check.day),
        ],
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: Tokens.spaceS,
      actions: [
        TextButton(
          key: const ValueKey('overload-add-anyway'),
          onPressed: () => Navigator.pop(context, const AddAnyway()),
          child: const Text('Add anyway'),
        ),
        TextButton(
          key: const ValueKey('overload-pick'),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: suggested ?? check.day,
              firstDate: DateTime(check.day.year - 1),
              lastDate: DateTime(check.day.year + 5),
            );
            if (picked != null && context.mounted) {
              Navigator.pop(context, MoveTo(picked));
            }
          },
          child: const Text('Pick a day'),
        ),
        if (suggested != null)
          FilledButton(
            key: const ValueKey('overload-move'),
            onPressed: () => Navigator.pop(context, MoveTo(suggested)),
            child: Text(
              'Move to ${_weekdayNames[suggested.weekday - 1].substring(0, 3)}',
            ),
          ),
      ],
    );
  }
}

/// Mini bar chart of one week's load: one bar per day on a shared baseline,
/// a 100% capacity marker, the day being planned emphasised. Values are
/// printed as text under the bars (never colour alone). Sizes to its
/// content, so large text settings never overflow it.
class WeekLoadChart extends StatelessWidget {
  const WeekLoadChart({super.key, required this.week, this.highlight});

  final List<DayLoad> week;
  final DateTime? highlight;

  static const _plotHeight = 72.0;
  static const _maxPercent = 150;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = [
      for (final d in week)
        '${_weekdayNames[d.day.weekday - 1]} ${formatHours(d.loadMin)}'
            '${d.isFull ? ', over capacity' : ''}',
    ].join('; ');
    const markerTop = _plotHeight - _plotHeight * 100 / _maxPercent;

    double barHeight(DayLoad d) => d.loadMin == 0
        ? 0
        : (_plotHeight * d.percent.clamp(0, _maxPercent) / _maxPercent).clamp(
            2.0,
            _plotHeight,
          );

    return Semantics(
      label: 'Week load: $label',
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('week-load-chart'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in week)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: _plotHeight,
                    child: Stack(
                      children: [
                        // 100% capacity marker, continuous across columns.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: markerTop,
                          child: Container(height: 1, color: scheme.outline),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 14,
                            height: barHeight(d),
                            decoration: BoxDecoration(
                              color: d.day == highlight
                                  ? scheme.primary
                                  : scheme.primary.withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _weekdayNames[d.day.weekday - 1].substring(0, 1),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: d.day == highlight
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                  Text(
                    d.loadMin == 0 ? '–' : formatHours(d.loadMin),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Upcoming heatmap (PBI-011 AC5): 7 day cells with load %, single-hue
/// sequential fill; over-capacity days carry ⚠ + "Full" (not colour alone).
class LoadHeatmap extends StatelessWidget {
  const LoadHeatmap({super.key, required this.days});

  final List<DayLoad> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      key: const ValueKey('load-heatmap'),
      padding: const EdgeInsets.fromLTRB(
        Tokens.spaceM,
        Tokens.spaceM,
        Tokens.spaceM,
        0,
      ),
      // Equal-height cells even when a label wraps (large text sizes).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in days)
              Expanded(
                child: Semantics(
                  label:
                      '${_weekdayNames[d.day.weekday - 1]}: ${d.percent} percent'
                      '${d.isFull ? ', full' : ''}',
                  excludeSemantics: true,
                  child: Container(
                    key: ValueKey('heat-${d.day.day}'),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      vertical: Tokens.spaceS,
                    ),
                    decoration: BoxDecoration(
                      // Sequential: 0% → faint, 100%+ → full primary.
                      color: scheme.primary.withValues(
                        alpha: 0.08 + 0.72 * (d.percent.clamp(0, 100) / 100),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: d.isFull
                          ? Border.all(color: scheme.error, width: 2)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekdayNames[d.day.weekday - 1].substring(0, 3),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: d.percent > 55
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                        ),
                        Text(
                          '${d.percent}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: d.percent > 55
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                        ),
                        // Same height for every cell; only full days say so.
                        Text(
                          d.isFull ? '⚠ Full' : ' ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
