import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../data/reminder_service.dart';
import '../domain/reminder_planner.dart';
import '../reminder_sync.dart';
import 'notification_gateway.dart';

const _channelId = 'reminders';
const _channelName = 'Reminders';

const _actionTitles = {
  ReminderActions.done: 'Done ✓',
  ReminderActions.paid: 'Paid ✓',
  ReminderActions.snooze: 'Snooze',
  ReminderActions.renew: 'Set renewal task',
  ReminderActions.dismiss: 'Dismiss',
};

/// `flutter_local_notifications` implementation of [NotificationGateway].
/// Device-only: exercised on Android/iOS, not in unit tests.
class LocalNotificationsGateway implements NotificationGateway {
  LocalNotificationsGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _exactAllowed = false;

  @override
  Future<void> init(NotificationActionCallback onAction) async {
    tzdata.initializeTimeZones();
    await refreshTimezone();
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked in context instead (requestPermission).
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            for (final kind in ReminderKind.values)
              DarwinNotificationCategory(
                kind.name,
                actions: [
                  for (final a in ReminderActions.forKind(kind))
                    DarwinNotificationAction.plain(a, _actionTitles[a]!),
                ],
              ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onAction(r.actionId, r.payload),
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationAction,
    );
    _exactAllowed = await _canScheduleExact();
  }

  @override
  Future<void> refreshTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission() ?? false;
      if (!await _canScheduleExact()) {
        await android?.requestExactAlarmsPermission();
      }
      _exactAllowed = await _canScheduleExact();
      return granted;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> replaceAll(List<PlannedNotification> planned) async {
    await _plugin.cancelAllPendingNotifications();
    for (final n in planned) {
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: tz.TZDateTime.from(n.fireAt, tz.local),
        title: n.title,
        body: n.body,
        payload: n.payload,
        androidScheduleMode: _exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Task, payment and document reminders',
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              for (final a in n.actions)
                AndroidNotificationAction(a, _actionTitles[a]!),
            ],
          ),
          iOS: DarwinNotificationDetails(categoryIdentifier: n.kind.name),
        ),
      );
    }
  }

  Future<bool> _canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
  }
}

/// Runs when an action button is tapped while the app isn't in the
/// foreground (Android background isolate). Opens its own connection to the
/// shared database, applies the action, and reschedules.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationAction(NotificationResponse r) async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  try {
    final repos = await Repositories.open(db);
    await ReminderService(repos).handleAction(r.actionId, r.payload);
    final gateway = LocalNotificationsGateway();
    await gateway.init((_, _) async {});
    await ReminderSync(repos, gateway).resync();
  } finally {
    await db.close();
  }
}
