// عقد مستودع الأحاديث: كل ما تعرضه ميزة الحديث يُقرأ من ملفات JSON الموثقة.
//
// الخط الأحمر: لا يولّد التطبيق متناً ولا سياقاً ولا حكماً؛ يعرض ما في الملفات
// كما هو، ويرفض أي حديث تكشف عنه فحوص السلامة خللاً.
//
// العزل: هذا المستودع لا يعرف شيئاً عن محطات السيرة ولا عن حواضر الرواية؛
// بيانات السيرة لها مستودعها المستقل SeerahRepository.

import '../data/models/models.dart';

/// مستودع الأحاديث.
abstract interface class HadithRepository {
  /// المنهج: ترتيب الأوراد وسياسة القفل اليومي.
  Future<CurriculumManifest> loadCurriculum();

  /// فهرس تراجم الرواة.
  Future<NarratorCatalog> loadNarrators();

  /// فهرس المصادر.
  Future<SourceCatalog> loadSources();

  /// بنك العبارات التراثية.
  Future<WisdomCatalog> loadWisdom();

  /// حديث واحد بعد فحص سلامته مع الفهارس.
  Future<HadithDailyModel> loadHadith(String hadithId);
}

/// خطأ سلامة يمنع عرض حديث.
class ContentIntegrityException implements Exception {
  const ContentIntegrityException(this.hadithId, this.issues);

  /// الحديث المرفوض.
  final String hadithId;

  /// المشكلات المكتشفة.
  final List<String> issues;

  @override
  String toString() {
    return 'ContentIntegrityException($hadithId): ${issues.join('; ')}';
  }
}

/// حديث غير موجود في المنهج.
class UnknownHadithException implements Exception {
  const UnknownHadithException(this.hadithId);

  /// المعرّف المطلوب.
  final String hadithId;

  @override
  String toString() => 'UnknownHadithException($hadithId)';
}
