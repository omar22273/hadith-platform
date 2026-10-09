// بدائل الاختبار لخدمات المنصة: المشاركة، والتنبيهات، ومنتقي ملف النسخة.

import 'package:hadith_platform/core/share/share_service.dart';
import 'package:hadith_platform/features/backup/data/backup_file_picker.dart';
import 'package:hadith_platform/features/reminders/application/notification_service.dart';

/// ملف شورك.
class SharedFile {
  const SharedFile({required this.bytes, required this.fileName, required this.mimeType});

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}

/// مشاركة تسجل ما أُرسل إليها.
class FakeShareService implements ShareService {
  final List<String> texts = <String>[];
  final List<SharedFile> files = <SharedFile>[];

  /// حين يكون true تفشل المشاركة كما لو لم تتوفر قائمة المشاركة.
  bool failing = false;

  @override
  Future<void> shareText(String text, {String? subject}) async {
    if (failing) {
      throw StateError('share unavailable');
    }
    texts.add(text);
  }

  @override
  Future<void> shareFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    if (failing) {
      throw StateError('share unavailable');
    }
    files.add(SharedFile(bytes: bytes, fileName: fileName, mimeType: mimeType));
  }
}

/// جدولة مسجلة.
class ScheduledReminder {
  const ScheduledReminder({required this.hour, required this.minute, required this.title, required this.body});

  final int hour;
  final int minute;
  final String title;
  final String body;
}

/// خدمة تنبيهات تحاكي منح الإذن أو رفضه.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permissionGranted = true, this.available = true});

  /// هل يمنح المستخدم الإذن عند طلبه.
  bool permissionGranted;

  /// هل الخدمة متاحة.
  final bool available;

  /// هل الإذن ممنوح الآن (قبل أي طلب).
  bool currentlyGranted = false;

  final List<ScheduledReminder> scheduled = <ScheduledReminder>[];
  int cancelCount = 0;
  int permissionRequests = 0;
  int openedSettings = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<bool> hasPermission() async => currentlyGranted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    currentlyGranted = permissionGranted;
    return permissionGranted;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    scheduled.add(ScheduledReminder(hour: hour, minute: minute, title: title, body: body));
  }

  @override
  Future<void> cancelDaily() async {
    cancelCount++;
  }

  @override
  Future<bool> openSystemSettings() async {
    openedSettings++;
    return true;
  }
}

/// منتقي ملف يعيد نصاً محدداً (أو null كأن المستخدم ألغى).
class FakeBackupFilePicker implements BackupFilePicker {
  FakeBackupFilePicker([this.text]);

  /// ما يُعاد عند الاختيار.
  String? text;

  int picks = 0;

  @override
  Future<String?> pickBackupText() async {
    picks++;
    return text;
  }
}
