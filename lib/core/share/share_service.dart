// خدمة المشاركة: واجهة مجردة فوق قائمة المشاركة القياسية في النظام، ليبقى
// التطبيق وما يختبره مستقلاً عن المنصة. تشارك النص أو ملفاً (صورة البطاقة
// والنسخة الاحتياطية).

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// عقد المشاركة.
abstract interface class ShareService {
  /// يفتح قائمة المشاركة القياسية بالنص. يرمي عند تعذر فتحها.
  Future<void> shareText(String text, {String? subject});

  /// يفتح قائمة المشاركة القياسية بملف محتواه [bytes] باسم [fileName]. يرمي عند
  /// تعذر إنشاء الملف أو فتح القائمة.
  Future<void> shareFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
  });
}

/// التنفيذ الإنتاجي فوق share_plus.
class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  static const String _folderPrefix = 'hadith_share_';

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  @override
  Future<void> shareFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    // الملف يُكتب في مجلد الكاش المؤقت للتطبيق، وهو مسار يغطيه FileProvider
    // الخاص بالمشاركة، ويبقى حتى يقرأه التطبيق المستقبل ثم ينظفه النظام.
    final Directory cache = await getTemporaryDirectory();
    await _removeStaleFolders(cache);
    final Directory folder = await cache.createTemp(_folderPrefix);
    final File file = File('${folder.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: mimeType, name: fileName)],
        subject: subject,
        text: text,
      ),
    );
  }

  /// يحذف مجلدات مشاركة سابقة مضى عليها أكثر من ساعة، دون أن يفشل منه شيء.
  Future<void> _removeStaleFolders(Directory cache) async {
    try {
      final DateTime threshold = DateTime.now().subtract(const Duration(hours: 1));
      await for (final FileSystemEntity entity in cache.list()) {
        final String name = entity.path.split(Platform.pathSeparator).last;
        if (entity is Directory && name.startsWith(_folderPrefix) && entity.statSync().modified.isBefore(threshold)) {
          await entity.delete(recursive: true);
        }
      }
    } on Object {
      // تنظيف اختياري.
    }
  }
}

/// خدمة المشاركة المستخدمة في التطبيق.
final Provider<ShareService> shareServiceProvider = Provider<ShareService>(
  (Ref ref) => const SharePlusShareService(),
);
