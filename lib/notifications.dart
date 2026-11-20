import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'db.dart';

class NotificationHelper {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onAction,
      onDidReceiveBackgroundNotificationResponse: _onAction,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    _ready = true;
  }

  @pragma('vm:entry-point')
  static Future<void> _onAction(NotificationResponse res) async {
    if (res.actionId == 'mark_done' && res.payload != null) {
      final id = int.tryParse(res.payload!);
      if (id != null) {
        await DatabaseHelper.toggleHabitDate(id, DateTime.now(), false);
      }
    }
  }

  static Future<void> scheduleHabit(int id, String title, String hhmm) async {
    await init();
    final parts = hhmm.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = int.tryParse(parts.elementAt(1)) ?? 0;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_reminders',
        'Habit Reminders',
        channelDescription: 'Daily reminders for your habits',
        importance: Importance.max,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction('mark_done', 'Mark done', showsUserInterface: false, cancelNotification: true),
        ],
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: 'Habit Reminder',
      body: title,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '$id',
    );
  }

  static Future<void> cancelHabit(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }
}
