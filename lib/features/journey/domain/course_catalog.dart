// منهاج المتون المتدرج: المساق الأول (الأربعون النووية) مفتوح بالكامل،
// وتأتي بعده ثلاثة مساقات مقفلة بترتيب منهجي متدرج يمنع الملل ويدعم التنوع.
//
// هذه بيانات عرض للمساقات فقط (العناوين والمصنفون والنبذ التعريفية)؛ لا متون فيها
// ولا أحكام، ولا يُفتح مساق قبل أن يُعدّ محتواه ويُوثَّق بملفات JSON.

import 'package:flutter/foundation.dart';

import '../../../core/text/arabic_digits.dart';

/// حالة المساق.
enum CourseStatus {
  /// مفتوح للتعلم.
  open,

  /// مقفل حتى إتمام المساق الأول.
  locked,
}

/// مساق في المنهاج.
@immutable
class CurriculumCourse {
  const CurriculumCourse({
    required this.id,
    required this.title,
    required this.author,
    required this.status,
    required this.order,
    required this.summary,
    required this.volumeLabel,
  });

  /// المعرّف.
  final String id;

  /// العنوان.
  final String title;

  /// المصنف أو المنتقي.
  final String author;

  /// الحالة.
  final CourseStatus status;

  /// ترتيبه في المنهاج، من واحد.
  final int order;

  /// نبذة تعريفية ميسرة بطبيعة المساق وفائدته.
  final String summary;

  /// حجم المساق (عدد الأحاديث وباقاتها).
  final String volumeLabel;

  /// هل هو مقفل.
  bool get locked => status == CourseStatus.locked;

  /// ترتيبه مكتوباً: «المساق الثاني».
  String get orderLabel => 'المساق ${CourseCatalog.ordinal(order)}';
}

/// المنهاج.
abstract final class CourseCatalog {
  /// معرّف المساق الأول.
  static const String foundationId = 'nawawi40';

  /// عدد أحاديث المساق الأول، وبإتمامها تُفتح المساقات اللاحقة.
  static const int foundationHadithCount = 42;

  /// وسم القفل المعروض على كل مساق لاحق.
  static const String lockedNote = 'تُفتح بعد إتمام مسار الأربعين النووية';

  /// رسالة التحفيز في ورقة المعاينة.
  static final String motivation =
      'يُفتح هذا المساق تلقائياً فور ختمك للأحاديث الـ ${arabicDigits(foundationHadithCount)} الحالية بالورد اليومي.';

  /// المساقات بترتيبها المنهجي.
  static final List<CurriculumCourse> courses = <CurriculumCourse>[
    CurriculumCourse(
      id: foundationId,
      title: 'الأربعون النووية',
      author: 'الإمام النووي',
      status: CourseStatus.open,
      order: 1,
      summary: 'الأصل الجامع لقواعد الدين، وهو مساقك الحالي: ${arabicDigits(foundationHadithCount)} حديثاً بوردٍ يومي.',
      volumeLabel: '${arabicDigits(foundationHadithCount)} حديثاً',
    ),
    const CurriculumCourse(
      id: 'tatimmat_al_khamsin',
      title: 'تتمة الخمسين الرجبية',
      author: 'الحافظ ابن رجب',
      status: CourseStatus.locked,
      order: 2,
      summary: 'ثمانية أحاديث جامعة ألحقها الحافظ ابن رجب بأحاديث النووي لتكتمل بها قواعد الدين خمسين حديثاً.',
      volumeLabel: '٨ أحاديث',
    ),
    const CurriculumCourse(
      id: 'miat_al_hady',
      title: 'مائة الهَدْي (عشريات السنن المتنوعة)',
      author: 'انتقاء منصة هَدْي',
      status: CourseStatus.locked,
      order: 3,
      summary: 'مائة حديث منتقاة في عشر باقات، في كل باقة عشرة أحاديث تتنوع بين العقيدة والعبادة والأخلاق والفقه والأحاديث القدسية، '
          'فتنتقل بين الفنون ولا يتسلل إليك الملل.',
      volumeLabel: '١٠٠ حديث في ١٠ باقات',
    ),
    const CurriculumCourse(
      id: 'safwat_al_muttafaq_alayh',
      title: 'صفوة المتفق عليه (نخبة الصحيحين)',
      author: 'الإمامان البخاري ومسلم',
      status: CourseStatus.locked,
      order: 4,
      summary: 'باقات عشرية مختارة من أصح ما اتفق عليه الشيخان: أحاديث رواها البخاري ومسلم معاً في صحيحيهما.',
      volumeLabel: 'باقات عشرية',
    ),
  ];

  /// المساقات اللاحقة المقفلة.
  static List<CurriculumCourse> get lockedCourses {
    return courses.where((CurriculumCourse course) => course.locked).toList(growable: false);
  }

  /// العدد الترتيبي مؤنثاً: الأول، الثاني، الثالث، الرابع.
  static String ordinal(int order) {
    const List<String> names = <String>['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر'];
    return order >= 1 && order <= names.length ? names[order - 1] : arabicDigits(order);
  }
}
