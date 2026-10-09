// بطاقة التقدم أعلى المسار: موضع القافلة ونسبة التقدم، والاستمرارية ووتيرة
// الأوراد، وحالة وِرد اليوم مع عدّ تنازلي هادئ إلى الفجر عند بلوغ الحصة،
// وزر مباشر إلى ميدان المراجعة.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../domain/journey_snapshot.dart';
import '../../domain/pacing.dart';
import 'wird_labels.dart';

/// بطاقة الملخص.
class JourneySummaryCard extends StatelessWidget {
  const JourneySummaryCard({
    super.key,
    required this.snapshot,
    required this.onOpenToday,
    required this.onOpenReview,
    required this.onBypassLock,
  });

  /// اللقطة.
  final JourneySnapshot snapshot;

  /// فتح بطاقة وِرد اليوم.
  final VoidCallback onOpenToday;

  /// الانتقال إلى ميدان المراجعة.
  final VoidCallback onOpenReview;

  /// تخطي قفل الفجر لأغراض التجربة.
  final VoidCallback onBypassLock;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final WirdNode? here = snapshot.nodes.isEmpty ? null : snapshot.caravanNode;
    final PacingState pacing = snapshot.pacing;
    return SmoothSurface(
      elevated: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      here == null
                          ? 'مسار الأربعين'
                          : '${wirdNumberLabel(here)} من ${arabicDigits(snapshot.plannedCount)} · '
                              '${snapshot.segments[here.segmentIndex].title}',
                      style: text.labelMedium?.copyWith(color: palette.inkSoft),
                    ),
                    Text(
                      here == null ? '' : wirdTitle(here),
                      style: AppTypography.heritageTitle(color: palette.ink, fontSize: 27),
                    ),
                    Text(
                      'المكتمل ${arabicDigits(snapshot.completedCount)} · المُعدّ ${arabicDigits(snapshot.preparedCount)} من ${arabicDigits(snapshot.plannedCount)}',
                      style: text.bodySmall?.copyWith(color: palette.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ProgressRing(fraction: snapshot.progressFraction),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              SoftChip(
                icon: Icons.local_fire_department_rounded,
                label: pacing.streakDays > 0
                    ? 'الاستمرارية: ${daysLabel(pacing.streakDays)}'
                    : 'ابدأ سلسلة الاستمرارية اليوم',
                background: palette.amberSoft,
                foreground: palette.amberText,
                borderColor: palette.amber.withValues(alpha: 0.35),
              ),
              SoftChip(
                icon: Icons.speed_rounded,
                label: 'الوتيرة: ${hadithCountLabel(pacing.dailyQuota)} يومياً',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TodayStrip(
            snapshot: snapshot,
            onOpenToday: onOpenToday,
            onOpenReview: onOpenReview,
            onBypassLock: onBypassLock,
          ),
        ],
      ),
    );
  }
}

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({
    required this.snapshot,
    required this.onOpenToday,
    required this.onOpenReview,
    required this.onBypassLock,
  });

  final JourneySnapshot snapshot;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenReview;
  final VoidCallback onBypassLock;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final PacingState pacing = snapshot.pacing;
    final String quotaLine = pacing.lockBypassed && pacing.quotaReached
        ? 'وِرد إضافي (القفل متخطّى للتجربة)'
        : 'وِرد اليوم · ${arabicDigits(pacing.completedInWindow + 1)} من ${arabicDigits(pacing.dailyQuota)}';
    switch (snapshot.todayKind) {
      case TodayKind.available:
        return SmoothSurface(
          color: palette.amberSoft,
          borderColor: palette.amber.withValues(alpha: 0.45),
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
          onTap: onOpenToday,
          semanticLabel: '$quotaLine: ${snapshot.nextItem?.title ?? ''}. افتح وِرد اليوم',
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      quotaLine,
                      style: text.labelSmall?.copyWith(
                        color: palette.amberText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      snapshot.nextItem?.title ?? '',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: palette.amberText),
            ],
          ),
        );
      case TodayKind.capReached:
        return SmoothSurface(
          color: palette.surfaceMuted,
          borderColor: palette.line,
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                snapshot.curriculum.dailyCap.completionMessage,
                style: AppTypography.athar(
                  color: palette.amberText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (snapshot.nextUnlockAt != null)
                FajrCountdown(
                  target: snapshot.nextUnlockAt!,
                  usesFallback: snapshot.unlockUsesFallback,
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onOpenReview,
                icon: const Icon(Icons.psychology_alt_rounded),
                label: const Text('إلى ميدان المراجعة'),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onBypassLock,
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('تخطي القفل يدوياً (للتجربة)'),
                ),
              ),
            ],
          ),
        );
      case TodayKind.curriculumFinished:
        return SmoothSurface(
          color: palette.emeraldSoft,
          borderColor: palette.emerald.withValues(alpha: 0.4),
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.verified_outlined, color: palette.emeraldText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'أتممتَ الأوراد المُعدّة في هذا الإصدار. تُضاف الأحاديث التالية مع اكتمال توثيقها ومراجعتها.',
                      style: text.bodyMedium?.copyWith(color: palette.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onOpenReview,
                icon: const Icon(Icons.psychology_alt_rounded),
                label: const Text('إلى ميدان المراجعة'),
              ),
            ],
          ),
        );
    }
  }
}

/// عدّ تنازلي هادئ إلى وقت الفتح، يتحدث كل نصف دقيقة.
class FajrCountdown extends ConsumerStatefulWidget {
  const FajrCountdown({super.key, required this.target, required this.usesFallback});

  /// وقت الفتح.
  final DateTime target;

  /// هل الوقت هو الاحتياطي في المنهج.
  final bool usesFallback;

  @override
  ConsumerState<FajrCountdown> createState() => _FajrCountdownState();
}

class _FajrCountdownState extends ConsumerState<FajrCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final Duration remaining = widget.target.difference(ref.read(clockProvider)());
    final String clock =
        '${arabicDigits(widget.target.hour)}:${arabicDigits(widget.target.minute.toString().padLeft(2, '0'))}';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_clock, size: 18, color: palette.inkSoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'يُفتح الوِرد الجديد عند الفجر · $clock'
              '${widget.usesFallback ? ' (الوقت الاحتياطي)' : ''} · بعد ${arabicCountdown(remaining)}',
              style: text.bodySmall?.copyWith(color: palette.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      label: 'التقدم في الأربعين ${arabicPercent(fraction)}',
      child: SizedBox.square(
        dimension: 84,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: fraction,
            track: palette.line,
            fill: palette.emerald,
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    arabicPercent(fraction),
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.1),
                  ),
                  Text(
                    'من الأربعين',
                    style: text.labelSmall?.copyWith(color: palette.inkSoft, height: 1.1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.track, required this.fill});

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 7;
    final Rect rect = (Offset.zero & size).deflate(stroke / 2);
    final Paint base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final double bounded = fraction < 0 ? 0 : (fraction > 1 ? 1 : fraction);
    final double sweep = math.pi * 2 * bounded;
    if (sweep > 0) {
      final Paint arc = Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.fraction != fraction || oldDelegate.track != track || oldDelegate.fill != fill;
  }
}
