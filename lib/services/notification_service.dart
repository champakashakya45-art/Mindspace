import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'mindspace_daily';
  static const _channelName = 'Daily Reminder';

  Future<void> init() async {
    tz.initializeTimeZones();

    // ── Sri Lanka timezone set ──
    tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) {},
    );

    final android2 = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android2?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Daily mood log reminder',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Daily mood log reminder',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  // ── Test notification (immediate) ──
  Future<void> showTestNotification() async {
    await _plugin.show(
      1,
      'MindSpace 🌿',
      'How are you feeling today? Take a moment to log your mood.',
      _details,
    );
  }

  // ── Schedule daily ──
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _plugin.cancel(0);

    // Sri Lanka time use karanawa
    final colombo = tz.getLocation('Asia/Colombo');
    final now = tz.TZDateTime.now(colombo);

    var scheduled = tz.TZDateTime(
      colombo,
      now.year, now.month, now.day,
      hour, minute, 0,
    );

    // Time passed nattam tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      0,
      'MindSpace 🌿',
      'How are you feeling today? Take a moment to log your mood.',
      scheduled,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);
    await prefs.setBool('reminder_enabled', true);
  }

  Future<void> cancelReminder() async {
    await _plugin.cancel(0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', false);
  }

  Future<Map<String, dynamic>> getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool('reminder_enabled') ?? false,
      'hour':    prefs.getInt('reminder_hour') ?? 20,
      'minute':  prefs.getInt('reminder_minute') ?? 0,
    };
  }
}