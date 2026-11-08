import '../domain/reminder_planner.dart';

/// Called when the user taps a notification or one of its action buttons.
typedef NotificationActionCallback = Future<void> Function(
  String? actionId,
  String? payload,
);

/// The phone's notification system, behind an interface so scheduling
/// logic is testable without a device (PBI-012 grooming).
abstract interface class NotificationGateway {
  /// Sets up channels, iOS categories and the action callback.
  Future<void> init(NotificationActionCallback onAction);

  /// Re-reads the device timezone (after a timezone change).
  Future<void> refreshTimezone();

  /// Asks for notification (and, on Android 14+, exact-alarm) permission.
  /// Called in context — the first time a reminder is created.
  Future<bool> requestPermission();

  /// Replaces every pending notification with [planned].
  Future<void> replaceAll(List<PlannedNotification> planned);
}

/// Does nothing — used on the web preview and before init.
class NoopNotificationGateway implements NotificationGateway {
  const NoopNotificationGateway();

  @override
  Future<void> init(NotificationActionCallback onAction) async {}

  @override
  Future<void> refreshTimezone() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<PlannedNotification> planned) async {}
}
