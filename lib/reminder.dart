import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The evening "오늘 하루 정리해볼까요?" reminder. A daily local
/// notification at a time the user picks; nothing is sent anywhere.
abstract final class Reminder {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 21;
  static bool _ready = false;

  /// Called when the user taps the reminder while the app is running.
  static void Function()? onOpen;

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (e) {
        debugPrint('CamTrip: unknown time zone, using UTC: $e');
      }
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_camtrip')),
        onDidReceiveNotificationResponse: (_) => onOpen?.call(),
      );
      _ready = true;
    } catch (e) {
      debugPrint('CamTrip: reminders unavailable: $e');
    }
  }

  /// True when this launch came from tapping the reminder.
  static Future<bool> openedFromReminder() async {
    if (!_ready) return false;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  /// Asks for the notification permission (Android 13+). False if refused.
  static Future<bool> askPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Every day at [hour]:[minute]. Inexact on purpose: no special alarm
  /// permission is needed and a few minutes late is fine for this.
  static Future<void> schedule(int hour, int minute) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: at,
      title: '오늘 하루 정리해볼까요?',
      body: '말로 남긴 메모와 영수증을 1분이면 정리해요',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening',
          '저녁 정리',
          channelDescription: '하루를 정리하자고 저녁에 한 번 알려줘요',
          color: Color(0xFF1E2547),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel() async {
    if (_ready) await _plugin.cancel(id: _id);
  }
}
