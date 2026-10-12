// عقد مستودع الأذكار النبوية: ملف الأذكار بعد فحص سلامته مع فهرس المصادر.
//
// الخط الأحمر: لا يُعرض ذكر لا يحمل نصه شاهداً منقولاً حرفياً؛ فنص الذكر جزء
// من نص أحد شواهده، وكل شاهد له موضعه ونصه.

import '../data/models/adhkar.dart';

/// مستودع الأذكار.
abstract interface class AdhkarRepository {
  /// ملف الأذكار بعد فحص سلامته.
  Future<AdhkarCatalog> loadCatalog();
}

/// خطأ سلامة يمنع عرض الأذكار.
class AdhkarIntegrityException implements Exception {
  const AdhkarIntegrityException(this.issues);

  /// المشكلات المكتشفة.
  final List<String> issues;

  @override
  String toString() => 'AdhkarIntegrityException: ${issues.join('; ')}';
}
