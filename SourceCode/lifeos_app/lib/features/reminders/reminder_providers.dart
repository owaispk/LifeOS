import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import 'data/reminder_service.dart';
import 'platform/notification_gateway.dart';

/// The phone's notification system. Overridden in `main()` with the real
/// gateway on Android/iOS; a no-op on the web preview and in tests.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => const NoopNotificationGateway(),
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(
    ref.watch(repositoriesProvider),
    now: ref.watch(nowProvider),
  ),
);

final taskRemindersProvider = StreamProvider.family<List<TaskReminder>, String>(
  (ref, taskId) => ref.watch(reminderServiceProvider).watchReminders(taskId),
);
