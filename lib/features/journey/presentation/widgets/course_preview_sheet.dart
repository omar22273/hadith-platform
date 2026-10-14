// ورقة معاينة المساق اللاحق: تُفتح عند لمس بطاقة مساق مقفل، بلغة بطاقة الحديث
// نفسها (سطح عاجي بلمسات كهرمانية): عنوان المساق ومصنفه، ونبذة ميسرة بطبيعته وفائدته،
// وشارة القفل، ورسالة تحفيز. لا متون فيها ولا أحكام؛ هي بيانات عرض للمساق فقط.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../../core/ui/wide_action_button.dart';
import '../../domain/course_catalog.dart';

/// يعرض ورقة معاينة المساق.
Future<void> showCoursePreview(BuildContext context, CurriculumCourse course) {
  return showSmoothSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => CoursePreviewSheet(course: course),
  );
}

/// محتوى ورقة المعاينة.
class CoursePreviewSheet extends StatelessWidget {
  const CoursePreviewSheet({super.key, required this.course});

  /// المساق.
  final CurriculumCourse course;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          course.orderLabel,
          style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          course.title,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 30),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Icon(Icons.menu_book_rounded, size: 18, color: palette.inkSoft),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                course.author,
                style: text.bodyMedium?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            SoftChip(
              key: const ValueKey<String>('course-lock-badge'),
              label: course.unlockCondition,
              icon: Icons.lock_rounded,
              background: palette.amberSoft,
              foreground: palette.amberText,
              borderColor: palette.amber.withValues(alpha: 0.35),
            ),
            SoftChip(label: course.volumeLabel, icon: Icons.format_list_numbered_rtl_rounded),
          ],
        ),
        const SizedBox(height: 16),
        SmoothSurface(
          color: palette.surfaceMuted,
          borderColor: palette.amber.withValues(alpha: 0.30),
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'نبذة عن المساق',
                style: text.labelLarge?.copyWith(color: palette.amberText, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                course.summary,
                key: const ValueKey<String>('course-summary'),
                style: text.bodyLarge?.copyWith(color: palette.ink, height: 1.9),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.wb_twilight_rounded, size: 20, color: palette.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                course.motivation,
                key: const ValueKey<String>('course-motivation'),
                style: text.bodyMedium?.copyWith(color: palette.inkSoft, height: 1.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        WideActionButton(
          label: 'أتابع مساري',
          subtitle: 'وِرد كل يوم يقرّبك من فتح هذا المساق',
          icon: Icons.route_rounded,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
