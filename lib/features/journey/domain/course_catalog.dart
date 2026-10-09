// منهاج المتون المتدرج: المساق الأساسي (الأربعين النووية) مفتوح بالكامل،
// والمساقات اللاحقة تظهر مقفلة حتى يُتمّ المستخدم الأربعين.
//
// هذه بيانات عرض للمساقات فقط (أسماء الكتب ومؤلفوها)؛ لا متون فيها ولا
// أحكام، ولا يُفتح مساق قبل أن يُعدّ محتواه ويُوثَّق بملفات JSON.

import 'package:flutter/foundation.dart';

/// حالة المساق.
enum CourseStatus {
  /// مفتوح للتعلم.
  open,

  /// مقفل حتى إتمام المساق الأساسي.
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
  });

  /// المعرّف.
  final String id;

  /// العنوان.
  final String title;

  /// المؤلف.
  final String author;

  /// الحالة.
  final CourseStatus status;

  /// ترتيبه في المنهاج.
  final int order;

  /// هل هو مقفل.
  bool get locked => status == CourseStatus.locked;
}

/// المنهاج.
abstract final class CourseCatalog {
  /// معرّف المساق الأساسي.
  static const String foundationId = 'nawawi40';

  /// وسم القفل المعروض على كل مساق لاحق.
  static const String lockedNote = 'تُفتح بعد إتمام مساق الأربعين النووية';

  /// المساقات بترتيبها.
  static const List<CurriculumCourse> courses = <CurriculumCourse>[
    CurriculumCourse(
      id: foundationId,
      title: 'الأربعين النووية',
      author: 'الإمام النووي',
      status: CourseStatus.open,
      order: 0,
    ),
    CurriculumCourse(
      id: 'umdat_al_ahkam',
      title: 'عمدة الأحكام',
      author: 'عبد الغني المقدسي',
      status: CourseStatus.locked,
      order: 1,
    ),
    CurriculumCourse(
      id: 'riyad_al_salihin',
      title: 'رياض الصالحين',
      author: 'الإمام النووي',
      status: CourseStatus.locked,
      order: 2,
    ),
    CurriculumCourse(
      id: 'sahih_al_bukhari',
      title: 'صحيح البخاري',
      author: 'الإمام البخاري',
      status: CourseStatus.locked,
      order: 3,
    ),
  ];

  /// المساقات اللاحقة المقفلة.
  static List<CurriculumCourse> get lockedCourses {
    return courses.where((CurriculumCourse course) => course.locked).toList(growable: false);
  }
}
