// التنبيه التشجيعي عند إتمام حصة اليوم: رسالة الإتمام من المنهج، والاستمرارية،
// وقفل الفجر مع عدّه التنازلي، وزر مباشر إلى ميدان المراجعة للتثبيت.
// ويتاح تخطي القفل يدوياً لأغراض التجربة.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_tab.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_sheet.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../../../core/ui/wide_action_button.dart';
import '../../../hadith/application/hadith_providers.dart';
import '../../application/pacing_notifier.dart';
import '../../domain/pacing.dart';
import 'journey_summary_card.dart';
import 'wird_labels.dart';

/// يعرض التنبيه التشجيعي.
Future<void> showWirdCompleteSheet(BuildContext context) {
  return showSmoothSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => const WirdCompleteSheet(),
  );
}

/// محتوى التنبيه.
class WirdCompleteSheet extends ConsumerWidget {
  const WirdCompleteSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final PacingState? pacing = ref.watch(pacingProvider).value;
    final String message = ref.watch(curriculumProvider).value?.dailyCap.completionMessage ??
        'أتممت وِردك اليومي';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: palette.emeraldGradient,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.emerald.withValues(alpha: 0.35),
                  blurRadius: 22,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox.square(
              dimension: 76,
              child: Icon(Icons.verified_rounded, size: 40, color: palette.onAccent),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.heritageTitle(color: palette.ink, fontSize: 25),
        ),
        const SizedBox(height: 8),
        if (pacing != null) ...<Widget>[
          Text(
            pacing.streakDays > 0
                ? 'استمراريتك: ${daysLabel(pacing.streakDays)} على التوالي'
                : 'بداية طيبة؛ الثبات يوماً بعد يوم يفتح الوتيرة الأعلى.',
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(color: palette.emeraldText, fontWeight: FontWeight.w700),
          ),
          if (pacing.nextTier != null && pacing.daysToNextTier != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'بقي ${daysLabel(pacing.daysToNextTier!)} على التوالي لإتاحة «${hadithCountLabel(pacing.nextTier!.perDay)} يومياً» في الإعدادات.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: palette.inkSoft),
              ),
            ),
          const SizedBox(height: 16),
          SmoothSurface(
            color: palette.surfaceMuted,
            borderColor: palette.line,
            radius: AppShapes.radiusMedium,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      pacing.lockBypassed ? Icons.lock_open_rounded : Icons.lock_clock,
                      size: 20,
                      color: palette.inkSoft,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pacing.lockBypassed
                            ? 'قفل الفجر متخطّى لأغراض التجربة؛ يمكنك فتح الوِرد التالي الآن.'
                            : 'أُغلق فتح الأحاديث الجديدة حتى فجر الغد؛ حصتك اليوم ${hadithCountLabel(pacing.dailyQuota)}.',
                        style: text.bodyMedium?.copyWith(color: palette.ink, height: 1.7),
                      ),
                    ),
                  ],
                ),
                if (!pacing.lockBypassed)
                  FajrCountdown(target: pacing.nextUnlockAt, usesFallback: pacing.usesFallbackTime),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        WideActionButton(
          label: 'إلى ميدان المراجعة',
          subtitle: 'ثبّت ما حفظت: بطاقات الغريب، وترتيب كلمات المتن، ومواقف التثبيت',
          icon: Icons.psychology_alt_rounded,
          onPressed: () => openAppTab(context, ref, AppTab.review),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => openAppTab(context, ref, AppTab.arbaeen),
          icon: const Icon(Icons.route_rounded),
          label: const Text('العودة إلى مسار الأربعين'),
        ),
        if (pacing != null && !pacing.lockBypassed)
          TextButton.icon(
            onPressed: () {
              unawaited(ref.read(pacingProvider.notifier).bypassTodayLock());
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('تخطي القفل يدوياً (لأغراض التجربة)'),
          ),
      ],
    );
  }
}
