import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder.dart';
import 'settings_repo.dart';

/// The operating-system side of reminders, behind an interface so everything else is testable.
abstract class ReminderBackend {
  /// Ask for the notification permission (Android 13+). True if notifications may be shown.
  Future<bool> requestPermission();

  /// Show a notification at [firstLocal] and then every day at the same clock time.
  Future<void> scheduleDaily(DateTime firstLocal, String title, String body);
  Future<void> cancel();
}

class LocalNotificationsBackend implements ReminderBackend {
  LocalNotificationsBackend();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  static const _id = 1;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // Null on Android 12 and older, where no permission is needed.
    return (await android?.requestNotificationsPermission()) ?? true;
  }

  @override
  Future<void> scheduleDaily(DateTime firstLocal, String title, String body) async {
    await _init();
    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime(tz.local, firstLocal.year, firstLocal.month, firstLocal.day, firstLocal.hour, firstLocal.minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          channelDescription: 'A short daily nudge to do your reviews',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // Inexact on purpose: no special "alarms" permission, and a few minutes of drift is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _id);
  }
}

class ReminderConfig {
  const ReminderConfig({required this.enabled, required this.hour, required this.minute});
  final bool enabled;
  final int hour, minute;
}

/// Turns the reminder on or off and keeps its next time right. Settings live in the database,
/// so they travel with backups. Never throws: a failing notification must not break the app.
class ReminderService {
  ReminderService(this.settings, this.backend, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final SettingsRepo settings;
  final ReminderBackend backend;
  final DateTime Function() _clock;

  static const enabledKey = 'reminder_enabled';
  static const hourKey = 'reminder_hour';
  static const minuteKey = 'reminder_minute';

  Future<ReminderConfig> config() async => ReminderConfig(
        enabled: await settings.get(enabledKey) == '1',
        hour: (await settings.getInt(hourKey, 19)).clamp(0, 23),
        minute: (await settings.getInt(minuteKey, 0)).clamp(0, 59),
      );

  /// Returns false (and stays off) if the learner refuses the permission.
  Future<bool> enable(int hour, int minute, {bool doneToday = false}) async {
    try {
      if (!await backend.requestPermission()) return false;
    } catch (_) {
      return false;
    }
    await settings.set(hourKey, '$hour');
    await settings.set(minuteKey, '$minute');
    await settings.set(enabledKey, '1');
    await _schedule(hour, minute, doneToday);
    return true;
  }

  Future<void> setTime(int hour, int minute, {bool doneToday = false}) async {
    await settings.set(hourKey, '$hour');
    await settings.set(minuteKey, '$minute');
    if ((await config()).enabled) await _schedule(hour, minute, doneToday);
  }

  Future<void> disable() async {
    await settings.set(enabledKey, '0');
    try {
      await backend.cancel();
    } catch (_) {}
  }

  /// Call whenever the state of today changes (app opened, reviews finished).
  Future<void> refresh({required bool doneToday}) async {
    final c = await config();
    if (!c.enabled) return;
    await _schedule(c.hour, c.minute, doneToday);
  }

  Future<void> _schedule(int hour, int minute, bool doneToday) async {
    try {
      final now = _clock();
      final first = nextReminder(now, hour, minute, doneToday: doneToday);
      await backend.scheduleDaily(first, kReminderTitle, reminderBody(first));
    } catch (_) {
      // Surfaced by the phone check ("Daily reminder"); never crash the app over a nudge.
    }
  }
}
