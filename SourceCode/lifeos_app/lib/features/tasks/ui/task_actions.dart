import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../domain/task_rules.dart';
import '../tasks_providers.dart';

/// Completes a task with haptic feedback and a 5-second Undo snackbar.
Future<void> completeWithUndo(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(taskServiceProvider);
  await HapticFeedback.mediumImpact();
  final result = await service.complete(task.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('undo-snackbar'),
        content: Text(
          result.nextTaskId == null
              ? 'Done: ${task.title}'
              : 'Done — next one scheduled',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => service.undoComplete(result),
        ),
      ),
    );
}

/// Shows the snooze menu (tonight / tomorrow / pick) and applies it.
/// Returns true if the task was snoozed.
Future<bool> snoozeTask(BuildContext context, WidgetRef ref, Task task) async {
  final now = ref.read(nowProvider)();
  final choice = await showModalBottomSheet<Object>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('snooze-tonight'),
            leading: const Text('🌙', style: TextStyle(fontSize: 24)),
            title: const Text('Tonight'),
            onTap: () => Navigator.pop(context, SnoozeOption.tonight),
          ),
          ListTile(
            key: const ValueKey('snooze-tomorrow'),
            leading: const Text('☀️', style: TextStyle(fontSize: 24)),
            title: const Text('Tomorrow morning'),
            onTap: () => Navigator.pop(context, SnoozeOption.tomorrow),
          ),
          ListTile(
            key: const ValueKey('snooze-pick'),
            leading: const Text('📅', style: TextStyle(fontSize: 24)),
            title: const Text('Pick a date & time'),
            onTap: () => Navigator.pop(context, 'pick'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;

  final DateTime? target;
  if (choice is SnoozeOption) {
    target = snoozeTarget(choice, now);
  } else {
    target = await pickDateTime(
      context,
      initial: now.add(const Duration(days: 1)),
    );
  }
  if (target == null) return false;
  await ref.read(taskServiceProvider).snooze(task.id, target);
  return true;
}

/// Date picker followed by a time picker. Null if either is cancelled.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime initial,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(initial.year - 1),
    lastDate: DateTime(initial.year + 5),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
