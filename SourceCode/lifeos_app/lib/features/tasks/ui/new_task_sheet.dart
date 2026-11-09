import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../domain/task_rules.dart';
import '../../reminders/reminder_providers.dart';
import '../tasks_providers.dart';
import 'task_actions.dart';
import '../../../core/l10n.dart';
import '../domain/nl_parser.dart';
import 'quick_parse.dart';
import 'task_tile.dart';

/// 2.4 New Task — a bottom sheet with one field; the full form lives under
/// "More options" (UI flow §2.4).
Future<void> showNewTaskSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    isScrollControlled: true,
    builder: (context) => const NewTaskSheet(),
  );
}

class NewTaskSheet extends ConsumerStatefulWidget {
  const NewTaskSheet({super.key});

  @override
  ConsumerState<NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends ConsumerState<NewTaskSheet> {
  final _title = TextEditingController();
  bool _expanded = false;
  bool _saving = false;

  DateTime? _dueDate;
  TimeOfDay? _time;
  int _priority = 1;
  String _domain = 'mind';
  String? _personId;
  RepeatFreq? _repeat;
  int _duration = 30;

  /// Natural-language parse of the title (PBI-010). Manual choices below
  /// win over it: picking a date/priority/domain by hand turns that part
  /// of the parse off.
  QuickParse _parse = const QuickParse('', ParsedTask(title: ''));
  bool _manualDate = false;
  bool _manualPriority = false;
  bool _manualDomain = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final p = _parse.effective;
    final useParsedDate =
        !_manualDate && p.dueAt(ref.read(nowProvider)()) != null;
    final date = useParsedDate ? p.dueAt(ref.read(nowProvider)()) : _dueDate;
    final time = useParsedDate
        ? (p.hasTime ? TimeOfDay(hour: p.hour!, minute: p.minute) : null)
        : _time;
    final picked = date == null
        ? null
        : time == null
        ? date
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    // Overload Shield (PBI-011): may move the day, or send us back to edit.
    final resolved = await confirmCapacity(
      context,
      ref,
      due: picked,
      durationMin: _duration,
    );
    if (resolved == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    final due = resolved.due;
    await ref
        .read(taskServiceProvider)
        .create(
          title: _parse.input == _title.text ? _parse.title : _title.text,
          due: due,
          allDay: time == null,
          priority: !_manualPriority && p.highPriority ? 2 : _priority,
          domain: !_manualDomain && p.domain != null ? p.domain! : _domain,
          personId: _personId,
          durationMin: _duration,
          repeat: _repeat,
        );
    // A timed task gets a default reminder → ask for permission in context.
    if (time != null) {
      await ref.read(notificationGatewayProvider).requestPermission();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    final today = startOfDay(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final persons = ref.watch(personsProvider).value ?? const [];
    final l = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.spaceM,
        right: Tokens.spaceM,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.spaceM,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.tkNewTask, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Tokens.spaceM),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('new-task-title'),
                    controller: _title,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: l.tkWhatNeedsDoing,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) => setState(
                      () => _parse = quickParse(text, ref.read(nowProvider)()),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                IconButton(
                  key: const ValueKey('new-task-mic'),
                  tooltip: l.speak,
                  onPressed: () {
                    Navigator.pop(context);
                    showVoiceOverlay(context);
                  },
                  icon: const Icon(Icons.mic_none),
                ),
                const SizedBox(width: Tokens.spaceS),
                FilledButton(
                  key: const ValueKey('new-task-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, Tokens.minTouchTarget),
                  ),
                  onPressed: _canSave ? _save : null,
                  child: Text(l.tkAdd),
                ),
              ],
            ),
            const SizedBox(height: Tokens.spaceS),
            if (!_manualDate)
              ParseChips(
                parse: _parse,
                onDrop: (part) => setState(() => _parse = _parse.drop(part)),
              ),
            const SizedBox(height: Tokens.spaceS),
            Wrap(
              spacing: Tokens.spaceS,
              children: [
                // Tapping a selected day again clears the date.
                _choice(l.today, _dueDate == today, () => _toggleDate(today)),
                _choice(
                  l.tomorrow,
                  _dueDate == tomorrow,
                  () => _toggleDate(tomorrow),
                ),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(
                    _dueDate == null ||
                            _dueDate == today ||
                            _dueDate == tomorrow
                        ? l.tkPickDate
                        : formatDay(_dueDate!, now: now),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? today,
                      firstDate: DateTime(today.year - 1),
                      lastDate: DateTime(today.year + 5),
                    );
                    if (picked != null) {
                      setState(() {
                        _dueDate = picked;
                        _manualDate = true;
                      });
                    }
                  },
                ),
                if (_dueDate != null)
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      _time == null
                          ? l.tkAllDay
                          : formatTime(
                              DateTime(0, 1, 1, _time!.hour, _time!.minute),
                            ),
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime:
                            _time ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      setState(() {
                        _time = picked;
                        _manualDate = true;
                      });
                    },
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('new-task-more'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? l.tkFewerOptions : l.tkMoreOptions),
              ),
            ),
            if (_expanded) ...[
              _Label(l.tkPriority),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(l.tkLow)),
                  ButtonSegment(value: 1, label: Text(l.tkMedium)),
                  ButtonSegment(value: 2, label: Text(l.tkHigh)),
                ],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() {
                  _priority = s.first;
                  _manualPriority = true;
                }),
              ),
              _Label(l.tkLifeArea),
              Wrap(
                spacing: Tokens.spaceS,
                children: [
                  for (final d in domainOrder)
                    ChoiceChip(
                      avatar: CircleAvatar(
                        backgroundColor: domainColor(d),
                        radius: 5,
                      ),
                      label: Text(domainLabel(d)),
                      selected: _domain == d,
                      onSelected: (_) => setState(() {
                        _domain = d;
                        _manualDomain = true;
                      }),
                    ),
                ],
              ),
              if (persons.isNotEmpty) ...[
                _Label(l.tkFor),
                Wrap(
                  spacing: Tokens.spaceS,
                  children: [
                    for (final p in persons)
                      ChoiceChip(
                        label: Text([p.avatar ?? '👤', p.name].join(' ')),
                        selected: _personId == p.id,
                        onSelected: (on) =>
                            setState(() => _personId = on ? p.id : null),
                      ),
                  ],
                ),
              ],
              _Label(l.tkRepeat),
              Wrap(
                spacing: Tokens.spaceS,
                children: [
                  _choice(
                    l.tkNever,
                    _repeat == null,
                    () => setState(() => _repeat = null),
                  ),
                  for (final f in RepeatFreq.values)
                    _choice(
                      RepeatRule(f).describe(),
                      _repeat == f,
                      () => setState(() => _repeat = f),
                    ),
                ],
              ),
              _Label(l.tkTakesAbout),
              Wrap(
                spacing: Tokens.spaceS,
                children: [
                  for (final m in [15, 30, 45, 60, 90, 120])
                    _choice(
                      m < 60
                          ? l.tkMinutes('$m')
                          : l.tkHours('${m / 60}'.replaceAll('.0', '')),
                      _duration == m,
                      () => setState(() => _duration = m),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleDate(DateTime day) => setState(() {
    _manualDate = true;
    _dueDate = _dueDate == day ? null : day;
    if (_dueDate == null) _time = null;
  });

  Widget _choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Tokens.spaceM, bottom: Tokens.spaceS),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}
