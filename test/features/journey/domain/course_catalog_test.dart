// منهاج المتون بترتيب هَدْي: الأربعون النووية ثم تتمة الخمسين الرجبية مفتوحتان على مسار واحد
// من خمسين محطة، ثم مائة الهَدْي، ثم صفوة المتفق عليه مقفلتان ببيانات عرض لا متون فيها.

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/config/brand.dart';
import 'package:hadith_platform/features/journey/domain/course_catalog.dart';

void main() {
  test('the curriculum follows the Hady order, with the first two courses open on one path', () {
    final List<String> titles = CourseCatalog.courses.map((CurriculumCourse c) => c.title).toList();
    expect(titles, <String>[
      'الأربعون النووية',
      'تتمة الخمسين الرجبية',
      'مائة الهَدْي (عشريات السنن المتنوعة)',
      'صفوة المتفق عليه (نخبة الصحيحين)',
    ]);
    expect(CourseCatalog.courses.map((CurriculumCourse c) => c.order), <int>[1, 2, 3, 4]);
    expect(
      CourseCatalog.courses.where((CurriculumCourse c) => !c.locked).map((CurriculumCourse c) => c.id),
      <String>[CourseCatalog.foundationId, CourseCatalog.rajabId],
    );
    expect(CourseCatalog.lockedCourses.length, 2);
    expect(CourseCatalog.foundationHadithCount + CourseCatalog.rajabHadithCount, CourseCatalog.pathHadithCount);
    expect(CourseCatalog.pathHadithCount, 50);
  });

  test('every locked course has an author, a summary, a volume and an ordinal label', () {
    final List<String> labels = CourseCatalog.lockedCourses.map((CurriculumCourse c) => c.orderLabel).toList();
    expect(labels, <String>['المساق الثالث', 'المساق الرابع']);
    for (final CurriculumCourse course in CourseCatalog.lockedCourses) {
      expect(course.author, isNotEmpty);
      expect(course.summary.length, greaterThan(40), reason: course.title);
      expect(course.volumeLabel, isNotEmpty);
    }
    expect(CourseCatalog.courses[1].volumeLabel, '٨ أحاديث');
    expect(CourseCatalog.courses[2].volumeLabel, contains('١٠٠'));
    expect(CourseCatalog.courses[1].unlockCondition, 'مفتوح');
    expect(CourseCatalog.courses[1].motivation, contains('٤٣'));
    expect(CourseCatalog.courses[1].motivation, contains('٥٠'));
  });

  test('each locked course carries its own agreed unlock condition, in chain order', () {
    final List<CurriculumCourse> locked = CourseCatalog.lockedCourses;
    expect(locked[0].unlockCondition, 'تُفتح بعد إتمام مسار تتمة الخمسين الرجبية');
    expect(locked[1].unlockCondition, 'تُفتح بعد إتمام مسار مائة الهَدْي');
    expect(locked[0].motivation, 'يُفتح هذا المساق تلقائياً فور ختمك لمساق «تتمة الخمسين الرجبية».');
    expect(CourseCatalog.foundationHadithCount, 42);
  });

  test('the Mi\'at al-Hady summary is the agreed editorial text', () {
    expect(
      CourseCatalog.courses[2].summary,
      'نخبة منتقاة من أصح ما ثبت عن النبي ﷺ وأوثقها إسناداً في دواوين السنة؛ مصوغة في عشر باقات حية تكسر الرتابة، '
      'وتنتقل بالدارس بين معالم العقيدة، ومكارم الأخلاق، وفقه المعاملات، والرقائق، والسنن اليومية.',
    );
  });

  test('the brand carries the Hady name and tagline', () {
    expect(Brand.appName, 'هَدْي');
    expect(Brand.platformName, 'منصة هَدْي');
    expect(Brand.tagline, 'على خُطاه ﷺ علماً وعملاً — مدارسة الحديث النبوي والسيرة والأذكار');
    expect(Brand.aboutSummary, isNot(contains('الحديث النبوي والتاريخ')));
  });
}
