// منهاج المتون المتدرج: المساقان الأول (الأربعون النووية) والثاني (تتمة الخمسين الرجبية)
// مفتوحان بالكامل على مسار واحد من خمسين محطة، وتأتي بعدهما مساقان مقفلان بترتيب منهجي
// متدرج يمنع الملل ويدعم التنوع.
//
// هذه بيانات عرض للمساقات فقط (العناوين والمصنفون والنبذ التعريفية)؛ لا متون فيها
// ولا أحكام، ولا يُفتح مساق قبل أن يُعدّ محتواه ويُوثَّق بملفات JSON.

import 'package:flutter/foundation.dart';

import '../../../core/text/arabic_digits.dart';

/// حالة المساق.
enum CourseStatus {
  /// مفتوح للتعلم.
  open,

  /// مقفل حتى إتمام المساق الذي يسبقه.
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
    required this.unlockCondition,
    required this.motivation,
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

  /// شرط فتح المساق، يظهر على بطاقته وفي ورقة معاينته.
  final String unlockCondition;

  /// رسالة التحفيز في ورقة المعاينة.
  final String motivation;

  /// هل هو مقفل.
  bool get locked => status == CourseStatus.locked;

  /// ترتيبه مكتوباً: «المساق الثاني».
  String get orderLabel => 'المساق ${CourseCatalog.ordinal(order)}';
}

/// المنهاج.
abstract final class CourseCatalog {
  /// معرّف المساق الأول.
  static const String foundationId = 'nawawi40';

  /// معرّف المساق الثاني (تتمة الخمسين الرجبية).
  static const String rajabId = 'tatimmat_al_khamsin';

  /// عدد أحاديث المساق الأول.
  static const int foundationHadithCount = 42;

  /// عدد أحاديث المساق الثاني، وهي المحطات ٤٣–٥٠.
  static const int rajabHadithCount = 8;

  /// عدد محطات المسار كله: المساقان الأول والثاني متصلان على مسار واحد.
  static const int pathHadithCount = foundationHadithCount + rajabHadithCount;

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
      unlockCondition: 'مفتوح',
      motivation: 'هذا مساقك الحالي: أتمّ وِردك اليومي لتصل إلى تتمة الخمسين.',
    ),
    CurriculumCourse(
      id: rajabId,
      title: 'تتمة الخمسين الرجبية',
      author: 'الحافظ ابن رجب',
      status: CourseStatus.open,
      order: 2,
      summary: 'ثمانية أحاديث جامعة ألحقها الحافظ ابن رجب بأحاديث النووي لتكتمل بها قواعد الدين خمسين حديثاً.',
      volumeLabel: '${arabicDigits(rajabHadithCount)} أحاديث',
      unlockCondition: 'مفتوح',
      motivation: 'يتصل هذا المساق بمسارك: تأتي محطاته من ${arabicDigits(foundationHadithCount + 1)} إلى ${arabicDigits(pathHadithCount)} بعد الأحاديث الـ ${arabicDigits(foundationHadithCount)}.',
    ),
    const CurriculumCourse(
      id: 'miat_al_hady',
      title: 'مائة الهَدْي (عشريات السنن المتنوعة)',
      author: 'انتقاء منصة هَدْي',
      status: CourseStatus.locked,
      order: 3,
      summary: 'نخبة منتقاة من أصح ما ثبت عن النبي ﷺ وأوثقها إسناداً في دواوين السنة؛ مصوغة في عشر باقات حية تكسر الرتابة، '
          'وتنتقل بالدارس بين معالم العقيدة، ومكارم الأخلاق، وفقه المعاملات، والرقائق، والسنن اليومية.',
      volumeLabel: '١٠٠ حديث في ١٠ باقات',
      unlockCondition: 'تُفتح بعد إتمام مسار تتمة الخمسين الرجبية',
      motivation: 'يُفتح هذا المساق تلقائياً فور ختمك لمساق «تتمة الخمسين الرجبية».',
    ),
    const CurriculumCourse(
      id: 'safwat_al_muttafaq_alayh',
      title: 'صفوة المتفق عليه (نخبة الصحيحين)',
      author: 'الإمامان البخاري ومسلم',
      status: CourseStatus.locked,
      order: 4,
      summary: 'باقات عشرية مختارة من أصح ما اتفق عليه الشيخان: أحاديث رواها البخاري ومسلم معاً في صحيحيهما.',
      volumeLabel: 'باقات عشرية',
      unlockCondition: 'تُفتح بعد إتمام مسار مائة الهَدْي',
      motivation: 'يُفتح هذا المساق تلقائياً فور ختمك لمساق «مائة الهَدْي».',
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
