// نص تذكير الورد اليومي ومعرّفاته الثابتة. النص تشجيعي مرتبط بالاستمرارية،
// ولا يتضمن متناً ولا حكماً.

/// ثوابت التذكير.
abstract final class ReminderContent {
  /// عنوان الإشعار.
  static const String title = 'وِردك اليومي من الأربعين النبوية';

  /// نص الإشعار.
  static const String body = 'حافظ على استمرارية مسيرتك وافتح حديث اليوم لتثبيت الورد.';

  /// معرّف الإشعار المجدول؛ إشعار واحد متكرر فقط، فإعادة الجدولة تستبدله.
  static const int notificationId = 4001;

  /// معرّف قناة الإشعارات في أندرويد.
  static const String channelId = 'daily_wird_reminder';

  /// اسم القناة كما يظهر في إعدادات النظام.
  static const String channelName = 'تذكير الورد اليومي';

  /// وصف القناة.
  static const String channelDescription = 'تنبيه يومي يذكّرك بفتح حديث اليوم والمحافظة على استمرارية الورد.';
}
