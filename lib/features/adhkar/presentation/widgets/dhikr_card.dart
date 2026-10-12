// بطاقة الذكر التفاعلية: اللمس في أي مساحة منها يحتسب ضغطة واحدة. عدّاد مرئي
// يتصاعد نحو العدد المسنون الثابت مع حلقة تقدم وعدد المتبقي. وعند بلوغ العدد
// تضيء البطاقة بهالة خضراء هادئة ويُقفل عدّها نهائياً (لا زيادة على المسنون).
//
// نص الذكر يُعرض بخط المتن مشكولاً كما في ملف البيانات حرفاً بحرف.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/feedback_colors.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../data/models/adhkar.dart';

/// بطاقة الذكر.
class DhikrCard extends StatelessWidget {
  const DhikrCard({
    super.key,
    required this.item,
    required this.position,
    required this.total,
    required this.count,
    required this.onTap,
  });

  /// الذكر.
  final DhikrItem item;

  /// رقم الذكر في الوِرد (يبدأ من 1).
  final int position;

  /// عدد أذكار الوِرد.
  final int total;

  /// ما عُدَّ من الذكر.
  final int count;

  /// ضغطة واحدة؛ لا تُستدعى بعد بلوغ العدد.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final FeedbackColors feedback = FeedbackColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool completed = count >= item.count;
    final int remaining = completed ? 0 : item.count - count;
    final double progress = (count / item.count).clamp(0.0, 1.0).toDouble();
    final Duration duration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 450);
    final ShapeBorder shape = AppShapes.rounded(
      AppShapes.radiusLarge,
      side: BorderSide(
        color: completed ? feedback.rightBorder : palette.line,
        width: completed ? 2.4 : 1,
      ),
    );
    final String label = completed
        ? '${item.title}: اكتمل العدد المسنون ${arabicDigits(item.count)}'
        : '${item.title}: ${arabicDigits(count)} من ${arabicDigits(item.count)}. المس البطاقة لاحتساب ضغطة';

    return Semantics(
      container: true,
      button: !completed,
      onTap: completed ? null : onTap,
      label: label,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          key: const ValueKey<String>('dhikr-card-surface'),
          duration: duration,
          curve: Curves.easeOutCubic,
          decoration: ShapeDecoration(
            color: completed ? palette.emeraldSoft : palette.surface,
            shape: shape,
            shadows: completed
                // هالة خضراء حول البطاقة المكتملة.
                ? <BoxShadow>[
                    BoxShadow(
                      color: feedback.rightBorder.withValues(alpha: 0.5),
                      blurRadius: 34,
                      spreadRadius: 3,
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 28,
                      spreadRadius: -16,
                      offset: const Offset(0, 14),
                    ),
                  ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey<String>('dhikr-card-tap'),
              // null بعد بلوغ العدد: لا ضغطة ولا تموّج، والقفل نهائي.
              onTap: completed ? null : onTap,
              customBorder: shape,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'الذكر ${arabicDigits(position)} من ${arabicDigits(total)}',
                      textAlign: TextAlign.center,
                      style: text.labelMedium?.copyWith(color: palette.amberText, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: AppTypography.heritageTitle(color: palette.ink, fontSize: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.text,
                      textAlign: TextAlign.center,
                      style: AppTypography.matnOf(
                        context,
                        color: palette.ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: _CounterRing(
                        count: count,
                        target: item.count,
                        progress: progress,
                        completed: completed,
                        duration: duration,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: duration,
                      child: completed
                          ? Row(
                              key: const ValueKey<String>('dhikr-complete-note'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(Icons.verified_rounded, size: 20, color: palette.emeraldText),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'اكتمل العدد المسنون',
                                    style: text.titleSmall?.copyWith(
                                      color: palette.emeraldText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              count == 0
                                  ? 'المس أي موضع في البطاقة للعدّ'
                                  : 'باقٍ ${arabicDigits(remaining)}',
                              key: const ValueKey<String>('dhikr-remaining'),
                              textAlign: TextAlign.center,
                              style: text.titleSmall?.copyWith(
                                color: palette.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حلقة التقدم والعدّاد المتصاعد نحو العدد المسنون.
class _CounterRing extends StatelessWidget {
  const _CounterRing({
    required this.count,
    required this.target,
    required this.progress,
    required this.completed,
    required this.duration,
  });

  final int count;
  final int target;
  final double progress;
  final bool completed;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final FeedbackColors feedback = FeedbackColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SizedBox.square(
      dimension: 132,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              return SizedBox.square(
                dimension: 132,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: palette.line,
                  color: completed ? feedback.rightBorder : palette.amber,
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                arabicDigits(count),
                key: const ValueKey<String>('dhikr-counter'),
                style: AppTypography.ui(
                  color: completed ? palette.emeraldText : palette.ink,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              Text(
                'من ${arabicDigits(target)}',
                style: text.labelMedium?.copyWith(color: palette.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
