// قسم «مساقات لاحقة» أسفل مسار الأربعين: بطاقات مقفلة لعمدة الأحكام ورياض
// الصالحين وصحيح البخاري، عليها وسم شرط الفتح.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../domain/course_catalog.dart';

/// قسم المساقات اللاحقة.
class LockedCoursesSection extends StatelessWidget {
  const LockedCoursesSection({super.key, required this.onLockedTap});

  /// لمس مساق مقفل.
  final ValueChanged<CurriculumCourse> onLockedTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
            child: Text(
              'مساقات لاحقة في المنهاج',
              style: AppTypography.heritageTitle(color: palette.ink, fontSize: 22),
            ),
          ),
          for (final CurriculumCourse course in CourseCatalog.lockedCourses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LockedCourseCard(course: course, onTap: () => onLockedTap(course), text: text),
            ),
        ],
      ),
    );
  }
}

class _LockedCourseCard extends StatelessWidget {
  const _LockedCourseCard({required this.course, required this.onTap, required this.text});

  final CurriculumCourse course;
  final VoidCallback onTap;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SmoothSurface(
      color: palette.surfaceMuted,
      borderColor: palette.line,
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      semanticLabel: '${course.title}، ${CourseCatalog.lockedNote}',
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: ShapeDecoration(
              color: palette.lockedSoft,
              shape: AppShapes.rounded(AppShapes.radiusSmall),
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(Icons.lock_rounded, color: palette.locked),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  course.title,
                  style: text.titleMedium?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
                ),
                Text(course.author, style: text.bodySmall?.copyWith(color: palette.locked)),
                const SizedBox(height: 4),
                Text(
                  CourseCatalog.lockedNote,
                  style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
