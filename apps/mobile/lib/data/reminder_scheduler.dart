import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

/// Schedules owner care reminders (docs/04 P3.12) as *local* device
/// notifications. No server push — these fire from the OS scheduler, so the
/// feature works with FCM/APNs still unwired.
///
/// Strategy: cancel-all + reschedule from the current reminder rows whenever
/// they change (or on app start). Honors the same gates alerts use — the
/// `user_settings` master notification toggle and quiet hours.
class ReminderScheduler {
  ReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channelId = 'care_reminders';

  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // ponytail: device local offset -> a fixed tz; DST-correct scheduling would
    // need flutter_timezone to read the real zone name. Fine for reminders.
    final name = tz.timeZoneDatabase.locations.keys.firstWhere(
      (l) => tz.getLocation(l).currentTimeZone.offset ==
          DateTime.now().timeZoneOffset.inMilliseconds,
      orElse: () => 'UTC',
    );
    tz.setLocalLocation(tz.getLocation(name));
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    // Android 13+ / iOS runtime prompt. Safe to call repeatedly.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  /// Reschedule one dog's reminders. Each reminder maps to a stable id derived
  /// from its uuid, so this overwrites its own prior schedule without touching
  /// other dogs' reminders — no `cancelAll`, which would clobber them.
  /// ponytail: a reminder deleted on another device stays scheduled until this
  /// device deletes it too; in-app delete cancels immediately via [cancel].
  Future<void> syncAll(List<CareReminder> reminders, UserSettings settings) async {
    for (final r in reminders) {
      await syncReminder(r, settings);
    }
  }

  /// Schedule a single reminder — or cancel it if it's inactive, notifications
  /// are off, or it's a one-off already in the past.
  Future<void> syncReminder(CareReminder r, UserSettings settings) async {
    try {
      await _ensureReady();
      if (!settings.notificationsEnabled || !r.active) {
        await _plugin.cancel(_notificationId(r.id));
        return;
      }
      final fireAt = effectiveFireTime(
        r.dueAt,
        settings.quietHoursStart,
        settings.quietHoursEnd,
      );
      if (r.repeat == ReminderRepeat.none && fireAt.isBefore(DateTime.now())) {
        await _plugin.cancel(_notificationId(r.id));
        return;
      }
      await _schedule(r, fireAt);
    } catch (e) {
      // Notifications must never break app startup or a save.
      debugPrint('ReminderScheduler.syncReminder failed: $e');
    }
  }

  Future<void> cancel(String reminderId) async {
    try {
      await _ensureReady();
      await _plugin.cancel(_notificationId(reminderId));
    } catch (e) {
      debugPrint('ReminderScheduler.cancel failed: $e');
    }
  }

  Future<void> _schedule(CareReminder r, DateTime fireAt) async {
    await _plugin.zonedSchedule(
      _notificationId(r.id),
      r.title,
      r.notes ?? 'Care reminder for your dog',
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Care reminders',
          channelDescription: 'Medication, feeding and appointment reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: switch (r.repeat) {
        ReminderRepeat.daily => DateTimeComponents.time,
        ReminderRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
        ReminderRepeat.none => null,
      },
    );
  }
}

/// Stable positive 31-bit id from the reminder uuid.
/// ponytail: hashCode collision is possible but astronomically unlikely for a
/// handful of per-owner reminders; a collision just reschedules over a sibling.
int _notificationId(String reminderId) => reminderId.hashCode & 0x7fffffff;

/// Pure, testable: if [due]'s time-of-day lands inside the quiet-hours window,
/// defer it to the window's end (same or next day); otherwise return [due]
/// unchanged. Handles overnight windows (start > end, e.g. 22:00 -> 07:00).
/// Times are "HH:MM" or "HH:MM:SS"; null start/end means no quiet hours.
DateTime effectiveFireTime(DateTime due, String? quietStart, String? quietEnd) {
  final start = _minutesOfDay(quietStart);
  final end = _minutesOfDay(quietEnd);
  if (start == null || end == null || start == end) return due;

  final t = due.hour * 60 + due.minute;
  final inQuiet =
      start < end ? (t >= start && t < end) : (t >= start || t < end);
  if (!inQuiet) return due;

  // Move to quiet-end. If end wraps past midnight relative to due, it's tomorrow.
  var target = DateTime(due.year, due.month, due.day, end ~/ 60, end % 60);
  if (!target.isAfter(due)) target = target.add(const Duration(days: 1));
  return target;
}

int? _minutesOfDay(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}
