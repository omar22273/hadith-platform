// عقد مستودع السنن المهجورة: ملفها بعد فحص سلامته مع فهرس المصادر.
//
// الخط الأحمر نفسه الذي للأذكار: لا تُعرض سنة لا يحمل نصها شاهداً منقولاً حرفياً.

import '../data/models/sunan.dart';

/// مستودع السنن.
abstract interface class SunanRepository {
  /// ملف السنن بعد فحص سلامته.
  Future<SunanCatalog> load();
}

/// خطأ سلامة يمنع عرض السنن.
class SunanIntegrityException implements Exception {
  const SunanIntegrityException(this.issues);

  /// المشكلات المكتشفة.
  final List<String> issues;

  @override
  String toString() => 'SunanIntegrityException: ${issues.join('; ')}';
}
