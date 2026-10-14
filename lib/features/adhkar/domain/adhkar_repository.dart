// عقد مستودع الأذكار النبوية: ملف كل فئة بعد فحص سلامته مع فهرس المصادر.
//
// الخط الأحمر: لا يُعرض ذكر لا يحمل نصه شاهداً منقولاً حرفياً؛ فنص الذكر جزء
// من نص أحد شواهده، وكل شاهد له موضعه ونصه.

import '../data/models/adhkar.dart';
import 'adhkar_category.dart';

/// مستودع الأذكار.
abstract interface class AdhkarRepository {
  /// ملف فئة من الفئات بعد فحص سلامته.
  Future<AdhkarCatalog> loadCategory(AdhkarCategory category);
}

/// خطأ سلامة يمنع عرض الأذكار.
class AdhkarIntegrityException implements Exception {
  const AdhkarIntegrityException(this.issues);

  /// المشكلات المكتشفة.
  final List<String> issues;

  @override
  String toString() => 'AdhkarIntegrityException: ${issues.join('; ')}';
}
