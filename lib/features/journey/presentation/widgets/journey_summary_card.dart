// بطاقة التقدم أعلى المسار: نسبة التقدم، وموضع القافلة، وحالة وِرد اليوم
// مع عدّ تنازلي هادئ إلى الفجر عند اكتمال وِرد اليوم.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../domain/journey_snapshot.dart';

/// بطاقة الملخص.
class JourneySummaryCard extends StatelessWidget {
  const JourneySummaryCard({
    super.key,
    required this.snapshot,
    required this.onOpenToday,
  });

  /// اللقطة.
  final JourneySnapshot snapshot;

  /// فتح بطاقة محطة القافلة.
  final VoidCallback onOpenToday;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final StationView here = snapshot.caravanStation;
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
                      'المحطة ${arabicDigits(here.station.order)} من ${arabicDigits(snapshot.stations.length)} · ${here.region.name}',
                      style: text.labelMedium?.copyWith(color: palette.inkSoft),
                    ),
                    Text(
                      here.station.name,
                      style: AppTypography.heritageTitle(color: palette.ink, fontSize: 28),
                    ),
                    if (here.station.event != null)
                      Text(
                        here.station.event!.title,
                        style: text.bodySmall?.copyWith(color: palette.inkSoft),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ProgressRing(fraction: snapshot.progressFraction),
            ],
          ),
          const SizedBox(height: 14),
          _TodayStrip(snapshot: snapshot, onOpenToday: onOpenToday),
        ],
      ),
    );
  }
}

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.snapshot, required this.onOpenToday});

  final JourneySnapshot snapshot;
  final VoidCallback onOpenToday;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    switch (snapshot.todayKind) {
      case TodayKind.available:
        return SmoothSurface(
          color: palette.amberSoft,
          borderColor: palette.amber.withValues(alpha: 0.45),
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
          onTap: onOpenToday,
          semanticLabel: 'وِرد اليوم: ${snapshot.nextItem?.title ?? ''}. افتح محطة اليوم',
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'وِرد اليوم ${arabicDigits(snapshot.nextDayNumber ?? 1)}',
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
            ],
          ),
        );
      case TodayKind.curriculumFinished:
        return SmoothSurface(
          color: palette.emeraldSoft,
          borderColor: palette.emerald.withValues(alpha: 0.4),
          radius: AppShapes.radiusMedium,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(Icons.verified_outlined, color: palette.emeraldText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'أتممتَ الأوراد المتاحة في هذه النسخة من المنهج. تُضاف المحطات التالية مع اكتمال إعدادها ومراجعتها.',
                  style: text.bodyMedium?.copyWith(color: palette.ink),
                ),
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
    _ticker = Timer.periodic(const Duration(seconds: 30), (Timer _) {
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
              'يُفتح وِرد الغد عند الفجر · $clock'
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
      label: 'التقدم في المسار ${arabicPercent(fraction)}',
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
                    'من المسار',
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
    final double sweep = math.pi * 2 * fraction.clamp(0.0, 1.0);
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
