// اختيار ملف النسخة من جهاز المستخدم عبر منتقي الملفات القياسي في النظام
// (Google Drive والتنزيلات وغيرها). الواجهة مجردة ليبقى ما فوقها قابلاً
// للاختبار دون منصة.

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/backup_codec.dart';

/// عقد اختيار الملف.
abstract interface class BackupFilePicker {
  /// يفتح المنتقي ويعيد نص الملف المختار، أو null إن ألغى المستخدم. يرمي
  /// [BackupFormatException] إن كان الملف كبيراً أو ليس نصاً.
  Future<String?> pickBackupText();
}

/// التنفيذ الإنتاجي فوق file_selector.
class FileSelectorBackupPicker implements BackupFilePicker {
  const FileSelectorBackupPicker();

  @override
  Future<String?> pickBackupText() async {
    // بلا مرشح امتداد عمداً: ملفات Drive وواتساب قد تصل بنوع MIME عام
    // فيخفيها المرشح، والفحص الحقيقي هو بنية الملف وبصمته.
    final XFile? file = await openFile();
    if (file == null) {
      return null;
    }
    if (await file.length() > BackupFormat.maxBytes) {
      throw const BackupFormatException('الملف أكبر من أن يكون نسخة احتياطية لهذا التطبيق.');
    }
    try {
      return utf8.decode(await file.readAsBytes());
    } on FormatException {
      throw const BackupFormatException('الملف ليس نصاً، فلا يمكن أن يكون نسخة احتياطية.');
    }
  }
}

/// منتقي الملفات المستخدم.
final Provider<BackupFilePicker> backupFilePickerProvider = Provider<BackupFilePicker>(
  (Ref ref) => const FileSelectorBackupPicker(),
);
