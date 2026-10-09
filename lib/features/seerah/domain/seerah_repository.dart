// عقد مستودع السيرة التاريخية: محطات رحلة السيرة بمشاهدها الثلاثة، وحدود
// خريطتها. مستقل تماماً عن مستودع الأحاديث.
//
// الخط الأحمر: نصوص المشاهد صياغة مقتصرة على شواهد منقولة بنصها من أمهات
// كتب السيرة والحديث، ويرفض المستودع أي محطة ينقصها شاهد لمشهد من مشاهدها.

import '../data/models/seerah_station.dart';
import 'seerah_map.dart';

/// مستودع السيرة.
abstract interface class SeerahRepository {
  /// ملف المحطات بعد فحص سلامته مع فهرس المصادر.
  Future<SeerahDataset> loadDataset();

  /// اليابسة المرسومة على خريطة الرحلة.
  Future<SeerahLand> loadLand();
}

/// خطأ سلامة يمنع عرض بيانات السيرة.
class SeerahIntegrityException implements Exception {
  const SeerahIntegrityException(this.issues);

  /// المشكلات المكتشفة.
  final List<String> issues;

  @override
  String toString() => 'SeerahIntegrityException: ${issues.join('; ')}';
}
