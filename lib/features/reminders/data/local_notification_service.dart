// الخدمة الحقيقية فوق flutter_local_notifications: جدولة إشعار يومي متكرر
// بالتوقيت المحلي للجهاز.
//
// - المنطقة الزمنية: يُقرأ اسمها من flutter_timezone، وإن تعذر يُستعمل أقرب
//   Etc/GMT بالإزاحة الحالية. وتُعاد الجدولة عند كل فتح للتطبيق فلا يتراكم
//   انحراف تغيّر التوقيت الصيفي.
// - نمط الجدولة غير الدقيق (inexactAllowWhileIdle): التذكير اليومي لا يحتاج
//   دقة الثانية، وبذلك لا يتطلب التطبيق إذن المنبهات الدقيقة (SCHEDULE_EXACT_ALARM).
// - إذن الإشعارات POST_NOTIFICATIONS يُطلب بحوار النظام عند التفعيل فقط.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../application/notification_service.dart';
import '../domain/reminder_content.dart';

/// خدمة التنبيهات المحلية.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;

  @override
  bool get isAvailable => defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      return;
    } on Object {
      // نكمل إلى البديل.
    }
    final Duration offset = DateTime.now().timeZoneOffset;
    if (offset.inMinutes % 60 != 0) {
      return;
    }
    final int hours = offset.inHours;
    final String name = hours == 0 ? 'UTC' : 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } on Object {
      // يبقى التوقيت العالمي افتراضياً.
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android {
    return _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  }

  @override
  Future<bool> hasPermission() async {
    await _ensureInitialized();
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) {
      return false;
    }
    return await android.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) {
      return false;
    }
    await android.requestNotificationsPermission();
    // الحكم النهائي من حالة الإشعارات الفعلية بعد الحوار، لا من قيمة الحوار وحدها.
    return await android.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime first = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!first.isAfter(now)) {
      first = first.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: ReminderContent.notificationId,
      title: title,
      body: body,
      scheduledDate: first,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          ReminderContent.channelId,
          ReminderContent.channelName,
          channelDescription: ReminderContent.channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDaily() async {
    await _ensureInitialized();
    await _plugin.cancel(id: ReminderContent.notificationId);
  }

  @override
  Future<bool> openSystemSettings() async {
    await _ensureInitialized();
    return await _android?.openAppNotificationSettings() ?? false;
  }
}
