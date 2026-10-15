// صفحة الذكر الواحدة داخل PageView، وهي ثلاثة عناصر بصرية لا غير:
//
// 1. نص الذكر المشكول بخط كبير في الوسط (يمرَّر داخلياً إن طال)، والآية بين ﴿ ﴾، وفوقه
//    شريط تنبيه رفيع إن كانت درجة الحديث دون الصحيح أو لا أصل له في الكتب الستة المثبتة.
// 2. منطقة اللمس السفلية: نصف الصفحة السفلي كله يستجيب للنقر في أي موضع منه.
// 3. فيها عدّاد دائري بارز يعرض «باقٍ N»، فإذا بلغ العدد المسنون أضاءت المنطقة
//    بهالة خضراء وانقفل العدّ نهائياً.
//
// الرأس (العنوان وشريط التقدم وزر المعلومات) من عمل الشاشة، لا الصفحة.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/feedback_colors.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../data/models/adhkar.dart';

/// صفحة ذكر.
class DhikrPage extends StatelessWidget {
  const DhikrPage({
    super.key,
    required this.item,
    required this.count,
    required this.onTap,
  });

  /// الذكر.
  final DhikrItem item;

  /// ما عُدَّ من الذكر.
  final int count;

  /// ضغطة واحدة؛ لا تُستدعى بعد بلوغ العدد.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(child: _DhikrText(item: item)),
        Expanded(child: _TapZone(item: item, count: count, onTap: onTap)),
      ],
    );
  }
}

/// نص الذكر في المنتصف مع تمرير داخلي حين يطول.
class _DhikrText extends StatelessWidget {
  const _DhikrText({required this.item});

  final DhikrItem item;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          key: ValueKey<String>('dhikr-text-scroll-${item.id}'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (item.caution != null) ...<Widget>[
                    _CautionBanner(itemId: item.id, message: item.caution!),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    item.displayText,
                    key: ValueKey<String>('dhikr-text-${item.id}'),
                    textAlign: TextAlign.center,
                    style: AppTypography.matnOf(
                      context,
                      color: palette.ink,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ).copyWith(height: 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// شريط التنبيه على بطاقة الذكر: درجة دون الصحيح، أو ذكر لا أصل له في الكتب الستة المثبتة.
class _CautionBanner extends StatelessWidget {
  const _CautionBanner({required this.itemId, required this.message});

  final String itemId;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      key: ValueKey<String>('dhikr-caution-$itemId'),
      color: palette.amberSoft,
      borderColor: palette.amber.withValues(alpha: 0.6),
      radius: AppShapes.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, size: 20, color: palette.amberText),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: text.bodySmall?.copyWith(color: palette.amberText, height: 1.6, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// النصف السفلي: GestureDetector يغطيه كله، فيحتسب أي نقرة داخله.
class _TapZone extends StatelessWidget {
  const _TapZone({required this.item, required this.count, required this.onTap});

  final DhikrItem item;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final FeedbackColors feedback = FeedbackColors.of(context);
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
        ? '${item.title}: اكتمل العدد المسنون'
        : '${item.title}: باقٍ ${arabicDigits(remaining)}. المس أي موضع لاحتساب ضغطة';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Semantics(
        container: true,
        button: !completed,
        onTap: completed ? null : onTap,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: ValueKey<String>('dhikr-tap-zone-${item.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: completed ? null : onTap,
            child: AnimatedContainer(
              key: ValueKey<String>('dhikr-zone-surface-${item.id}'),
              duration: duration,
              curve: Curves.easeOutCubic,
              decoration: ShapeDecoration(
                color: completed ? palette.emeraldSoft : palette.surface,
                shape: shape,
                shadows: completed
                    // هالة خضراء حول المنطقة المكتملة.
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
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double side = [
                    200.0,
                    constraints.maxHeight - 28,
                    constraints.maxWidth - 28,
                  ].reduce((double a, double b) => a < b ? a : b).clamp(96.0, 200.0).toDouble();
                  return Center(
                    child: _CounterRing(
                      itemId: item.id,
                      side: side,
                      remaining: remaining,
                      progress: progress,
                      completed: completed,
                      duration: duration,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// العدّاد الدائري: حلقة تقدم نحو العدد المسنون وفي وسطها «باقٍ N».
class _CounterRing extends StatelessWidget {
  const _CounterRing({
    required this.itemId,
    required this.side,
    required this.remaining,
    required this.progress,
    required this.completed,
    required this.duration,
  });

  final String itemId;
  final double side;
  final int remaining;
  final double progress;
  final bool completed;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final FeedbackColors feedback = FeedbackColors.of(context);
    return SizedBox.square(
      dimension: side,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              return SizedBox.square(
                dimension: side,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 11,
                  strokeCap: StrokeCap.round,
                  backgroundColor: palette.line,
                  color: completed ? feedback.rightBorder : palette.amber,
                ),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.all(side * 0.16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: completed
                  ? Column(
                      key: ValueKey<String>('dhikr-complete-$itemId'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.check_circle_rounded, size: 44, color: palette.emeraldText),
                        Text(
                          'اكتمل',
                          style: AppTypography.ui(
                            color: palette.emeraldText,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'باقٍ ${arabicDigits(remaining)}',
                      key: ValueKey<String>('dhikr-remaining-$itemId'),
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(
                        color: palette.ink,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
