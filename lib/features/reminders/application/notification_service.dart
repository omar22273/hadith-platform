// خدمة التنبيهات: واجهة مجردة فوق مكتبة الإشعارات المحلية، ليبقى منطق التذكير
// قابلاً للاختبار دون منصة. الافتراضي خدمة «غير متاحة» لا تفعل شيئاً، وتُستبدل
// في main بالخدمة الحقيقية.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// عقد خدمة التنبيهات.
abstract interface class NotificationService {
  /// هل تعمل التنبيهات على هذا الجهاز أصلاً.
  bool get isAvailable;

  /// هل إذن الإشعارات ممنوح الآن (بلا طلب).
  Future<bool> hasPermission();

  /// يطلب إذن الإشعارات (POST_NOTIFICATIONS على أندرويد ١٣ فأحدث) ويعيد هل مُنح.
  /// على الإصدارات الأقدم لا يظهر طلب ويعيد حال تفعيل الإشعارات.
  Future<bool> requestPermission();

  /// يجدول إشعاراً متكرراً كل يوم في الساعة والدقيقة المحددتين بالتوقيت المحلي،
  /// ويستبدل أي جدولة سابقة.
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  });

  /// يلغي الإشعار اليومي المجدول.
  Future<void> cancelDaily();

  /// يفتح إعدادات إشعارات التطبيق في النظام. يعيد false إن تعذر.
  Future<bool> openSystemSettings();
}

/// خدمة لا تفعل شيئاً: الافتراضي في الاختبارات وحيث لا منصة.
class UnavailableNotificationService implements NotificationService {
  const UnavailableNotificationService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelDaily() async {}

  @override
  Future<bool> openSystemSettings() async => false;
}

/// خدمة التنبيهات المستعملة؛ تستبدلها main بالخدمة الحقيقية.
final Provider<NotificationService> notificationServiceProvider = Provider<NotificationService>(
  (Ref ref) => const UnavailableNotificationService(),
);
