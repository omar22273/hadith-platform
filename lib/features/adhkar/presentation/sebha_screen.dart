// السبحة الذكية: تسبيح حر بعدّاد دائري هادئ.
//
// 1. الرأس: زر الرجوع إلى مركز الأذكار، والعنوان، وزر تصفير الجولة.
// 2. الخيارات: خمسة أذكار (سبحان الله، الحمد لله، الله أكبر، الصلاة على النبي ﷺ،
//    الاستغفار) ثم ثلاثة أزرار للعدد المستهدف: ٣٣ أو ١٠٠ أو حر بلا حد.
// 3. النصف السفلي كله منطقة لمس واحدة: كل نقرة تسبيحة، وفيها الحلقة الدائرية
//    (يتقدم قوسها نحو العدد المستهدف) والعدد، ومجموع الذكر والمجموع الكلي.
// 4. أسفل المنطقة زر «إعادة تعيين كافة الإحصائيات ↺»: يفتح AlertDialog للتأكيد،
//    وعند التأكيد تُصفَّر فوراً كل العدادات والمجاميع المحفوظة محلياً.
//
// تسبيحة بنقرة: اهتزاز خفيف selectionClick. بلوغ العدد المستهدف: اهتزاز متوسط
// مزدوج وهالة خضراء، وأول نقرة بعدها تبدأ جولة جديدة. الاختيار والمجاميع تُحفظ
// محلياً في الجهاز (StorageKeys.adhkarSebha).
//
// أسماء الأذكار عناوين خيارات فقط؛ لا نص نبوي مكتوب هنا.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/arabic_digits.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/feedback_colors.dart';
import '../../../core/ui/app_shapes.dart';
import '../application/sebha_controller.dart';

/// شاشة السبحة.
class SebhaScreen extends ConsumerStatefulWidget {
  const SebhaScreen({super.key});

  @override
  ConsumerState<SebhaScreen> createState() => _SebhaScreenState();
}

class _SebhaScreenState extends ConsumerState<SebhaScreen> {
  Timer? _secondPulse;

  @override
  void dispose() {
    _secondPulse?.cancel();
    super.dispose();
  }

  /// بلوغ العدد المستهدف: اهتزاز متوسط مزدوج بفاصل قصير.
  void _doublePulse() {
    unawaited(HapticFeedback.mediumImpact());
    _secondPulse?.cancel();
    _secondPulse = Timer(const Duration(milliseconds: 140), () {
      unawaited(HapticFeedback.mediumImpact());
    });
  }

  void _onTap() {
    final SebhaTapResult result = ref.read(sebhaProvider.notifier).tap();
    switch (result) {
      case SebhaTapResult.counted:
        unawaited(HapticFeedback.selectionClick());
      case SebhaTapResult.roundCompleted:
        _doublePulse();
    }
  }

  /// نافذة التأكيد؛ التصفير الشامل لا يجري إلا بعد «تصفير الكل».
  Future<void> _confirmResetAll() async {
    final AppPalette palette = AppPalette.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const ValueKey<String>('sebha-reset-all-dialog'),
        shape: AppShapes.rounded(AppShapes.radiusLarge),
        title: const Text('إعادة تعيين كافة الإحصائيات؟'),
        content: Text(
          'سيُصفَّر عدّاد الجولة الحالية ومجاميع الأذكار الخمسة المحفوظة في هذا الجهاز، '
          'ولا يمكن التراجع عن ذلك.',
          style: AppTypography.ui(color: palette.ink, fontSize: 14, height: 1.8),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('sebha-reset-all-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey<String>('sebha-reset-all-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تصفير الكل'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(sebhaProvider.notifier).resetAll();
      unawaited(HapticFeedback.lightImpact());
    }
  }

  @override
  Widget build(BuildContext context) {
    final SebhaState state = ref.watch(sebhaProvider);
    final SebhaController controller = ref.read(sebhaProvider.notifier);
    return Scaffold(
      key: const ValueKey<String>('adhkar-sebha'),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(canReset: state.count > 0, onReset: controller.resetRound),
            _Options(
              state: state,
              onDhikr: controller.selectDhikr,
              onTarget: controller.selectTarget,
            ),
            Expanded(child: _TapZone(state: state, onTap: _onTap)),
            _ResetAllButton(onPressed: _confirmResetAll),
          ],
        ),
      ),
    );
  }
}

/// الرأس: رجوع، وعنوان، وتصفير الجولة.
class _Header extends StatelessWidget {
  const _Header({required this.canReset, required this.onReset});

  final bool canReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: <Widget>[
          IconButton(
            key: const ValueKey<String>('sebha-back'),
            tooltip: 'الرجوع إلى مركز الأذكار',
            onPressed: () => Navigator.of(context).maybePop(),
            color: palette.inkSoft,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              'السبحة الذكية',
              key: const ValueKey<String>('sebha-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heritageTitle(color: palette.ink, fontSize: 24),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('sebha-reset'),
            tooltip: 'تصفير عدّاد الجولة',
            onPressed: canReset ? onReset : null,
            color: palette.inkSoft,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
    );
  }
}

/// زر «إعادة تعيين كافة الإحصائيات ↺» أسفل منطقة اللمس؛ خارجها كي لا تُحتسب نقرته تسبيحة.
class _ResetAllButton extends StatelessWidget {
  const _ResetAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final ShapeBorder shape = AppShapes.rounded(
      AppShapes.radiusSmall,
      side: BorderSide(color: palette.line),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Semantics(
        button: true,
        label: 'إعادة تعيين كافة الإحصائيات',
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: ShapeDecoration(color: palette.surface, shape: shape),
            child: Material(
              type: MaterialType.transparency,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey<String>('sebha-reset-all'),
                onTap: onPressed,
                customBorder: shape,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'إعادة تعيين كافة الإحصائيات',
                            textAlign: TextAlign.center,
                            style: AppTypography.ui(
                              color: palette.inkSoft,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.restart_alt_rounded, size: 20, color: palette.inkSoft),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// خيارات الذكر والعدد المستهدف.
class _Options extends StatelessWidget {
  const _Options({required this.state, required this.onDhikr, required this.onTarget});

  final SebhaState state;
  final ValueChanged<SebhaDhikr> onDhikr;
  final ValueChanged<SebhaTarget> onTarget;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SebhaDhikr dhikr in SebhaDhikr.values)
                _Pill(
                  key: ValueKey<String>('sebha-dhikr-${dhikr.id}'),
                  label: dhikr.label,
                  selected: dhikr == state.dhikr,
                  onTap: () => onDhikr(dhikr),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                'العدد',
                style: text.labelLarge?.copyWith(color: palette.inkSoft, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: <Widget>[
                    for (final SebhaTarget target in SebhaTarget.values) ...<Widget>[
                      Expanded(
                        child: _Pill(
                          key: ValueKey<String>('sebha-target-${target == SebhaTarget.free ? 'free' : target.limit}'),
                          label: target.limit > 0 ? arabicDigits(target.limit) : target.label,
                          selected: target == state.target,
                          onTap: () => onTarget(target),
                        ),
                      ),
                      if (target != SebhaTarget.values.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// زر اختيار بحواف ناعمة؛ المختار ذهبي هادئ.
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final ShapeBorder shape = AppShapes.rounded(
      AppShapes.radiusSmall,
      side: BorderSide(color: selected ? palette.amber : palette.line, width: selected ? 1.6 : 1),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: selected ? palette.amberSoft : palette.surface,
            shape: shape,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(
                        color: selected ? palette.amberText : palette.ink,
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// النصف السفلي: GestureDetector واحد يغطيه كله، فتُحتسب أي نقرة داخله.
class _TapZone extends StatelessWidget {
  const _TapZone({required this.state, required this.onTap});

  final SebhaState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final FeedbackColors feedback = FeedbackColors.of(context);
    final bool completed = state.roundComplete;
    final Duration duration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 300);
    final ShapeBorder shape = AppShapes.rounded(
      AppShapes.radiusLarge,
      side: BorderSide(
        color: completed ? feedback.rightBorder : palette.line,
        width: completed ? 2.4 : 1,
      ),
    );
    final String label = '${state.dhikr.label}: العدد ${arabicDigits(state.count)}'
        '${completed ? '، اكتملت الجولة' : ''}. المس أي موضع لاحتساب تسبيحة';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Semantics(
        container: true,
        button: true,
        onTap: onTap,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: const ValueKey<String>('sebha-tap-zone'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              key: const ValueKey<String>('sebha-zone-surface'),
              duration: duration,
              curve: Curves.easeOutCubic,
              decoration: ShapeDecoration(
                color: completed ? palette.emeraldSoft : palette.surface,
                shape: shape,
                shadows: completed
                    // هالة خضراء حول المنطقة عند إتمام الجولة.
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
                  final double side = <double>[
                    230.0,
                    constraints.maxHeight - 96,
                    constraints.maxWidth - 28,
                  ].reduce((double a, double b) => a < b ? a : b).clamp(96.0, 230.0).toDouble();
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _CounterRing(state: state, side: side, duration: duration),
                        const SizedBox(height: 10),
                        _Totals(state: state),
                      ],
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

/// الحلقة الدائرية: يتقدم قوسها نحو العدد المستهدف، وفي وسطها العدد.
class _CounterRing extends StatelessWidget {
  const _CounterRing({required this.state, required this.side, required this.duration});

  final SebhaState state;
  final double side;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final FeedbackColors feedback = FeedbackColors.of(context);
    final bool completed = state.roundComplete;
    final int limit = state.target.limit;
    final double progress = limit > 0 ? (state.count / limit).clamp(0.0, 1.0).toDouble() : 1.0;
    final Color arc = completed
        ? feedback.rightBorder
        : (limit > 0 ? palette.amber : palette.amber.withValues(alpha: 0.35));
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
                  key: const ValueKey<String>('sebha-ring'),
                  value: value,
                  strokeWidth: 11,
                  strokeCap: StrokeCap.round,
                  backgroundColor: palette.line,
                  color: arc,
                ),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.all(side * 0.14),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    state.dhikr.label,
                    key: const ValueKey<String>('sebha-dhikr-label'),
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(
                      color: palette.inkSoft,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    arabicDigits(state.count),
                    key: const ValueKey<String>('sebha-count'),
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(
                      color: completed ? palette.emeraldText : palette.ink,
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (completed)
                    Row(
                      key: const ValueKey<String>('sebha-round-complete'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.check_circle_rounded, size: 20, color: palette.emeraldText),
                        const SizedBox(width: 6),
                        Text(
                          'اكتملت الجولة',
                          style: AppTypography.ui(
                            color: palette.emeraldText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    )
                  else if (limit > 0)
                    Text(
                      'من ${arabicDigits(limit)}',
                      key: const ValueKey<String>('sebha-of-target'),
                      style: AppTypography.ui(color: palette.inkSoft, fontSize: 14, height: 1.3),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// مجموع الذكر المختار والمجموع الكلي المحفوظان محلياً.
class _Totals extends StatelessWidget {
  const _Totals({required this.state});

  final SebhaState state;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextStyle style = AppTypography.ui(color: palette.inkSoft, fontSize: 13, height: 1.5);
    final int dhikrTotal = state.dhikrTotal;
    final int grandTotal = state.grandTotal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'مجموع ${state.dhikr.label}: ${arabicDigits(dhikrTotal)}',
          key: const ValueKey<String>('sebha-dhikr-total'),
          textAlign: TextAlign.center,
          style: style,
        ),
        if (grandTotal != dhikrTotal)
          Text(
            'المجموع الكلي: ${arabicDigits(grandTotal)}',
            key: const ValueKey<String>('sebha-grand-total'),
            textAlign: TextAlign.center,
            style: style,
          ),
      ],
    );
  }
}
