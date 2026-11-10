import 'package:flutter/material.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../platform/calendar_source.dart';

/// The colour dot for an event: its calendar's colour, or the theme's
/// outline when the calendar has none.
Color eventColor(BuildContext context, CalEvent e) => e.colorValue == null
    ? Theme.of(context).colorScheme.outline
    : Color(e.colorValue!);

/// "09:30 – 10:15", or "All day".
String eventTimeLabel(AppLocalizations l, CalEvent e) => e.allDay
    ? l.calAllDay
    : e.end.isAfter(e.start)
    ? '${formatTime(e.start)} – ${formatTime(e.end)}'
    : formatTime(e.start);

/// One calendar event in Today or Upcoming. A distinct row from a task:
/// 📅, the calendar's colour, and no checkbox — it is not the user's
/// commitment and cannot be completed here (PBI-032).
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event});

  final CalEvent event;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('event-${event.id}'),
      minTileHeight: Tokens.rowTwoLine,
      leading: SizedBox(
        width: Tokens.minTouchTarget,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: Tokens.spaceXs,
              height: Tokens.spaceXl,
              decoration: BoxDecoration(
                color: eventColor(context, event),
                borderRadius: BorderRadius.circular(Tokens.spaceXxs),
              ),
            ),
            SizedBox(width: Tokens.spaceS),
            const Text('📅'),
          ],
        ),
      ),
      title: Text(
        event.title.isEmpty ? l.calEventsHeader : event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          eventTimeLabel(l, event),
          if (event.location.isNotEmpty) event.location,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      onTap: () => showEventSheet(context, event),
    );
  }
}

/// A small read-only sheet: what it is, when, where, and which calendar
/// it came from. Nothing here edits the event — that happens in the
/// phone's own calendar app.
Future<void> showEventSheet(BuildContext context, CalEvent event) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      final l = context.l10n;
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Tokens.spaceL),
          child: Column(
            key: const ValueKey('event-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: Tokens.spaceXs,
                    height: Tokens.spaceXl,
                    decoration: BoxDecoration(
                      color: eventColor(context, event),
                      borderRadius: BorderRadius.circular(Tokens.spaceXxs),
                    ),
                  ),
                  SizedBox(width: Tokens.spaceS),
                  Expanded(
                    child: Text(
                      event.title.isEmpty ? l.calEventsHeader : event.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              SizedBox(height: Tokens.spaceM),
              Text(
                '${formatDay(event.start, now: DateTime.now())} · '
                '${eventTimeLabel(l, event)}',
              ),
              if (event.location.isNotEmpty) ...[
                SizedBox(height: Tokens.spaceS),
                Text('${l.calLocation}: ${event.location}'),
              ],
              if (event.calendarName.isNotEmpty) ...[
                SizedBox(height: Tokens.spaceS),
                Text(
                  l.calFromCalendar(event.calendarName),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              SizedBox(height: Tokens.spaceM),
              Text(
                l.calReadOnly,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
