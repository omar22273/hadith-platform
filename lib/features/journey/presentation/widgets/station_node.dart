// كتلة المحطة التفاعلية: عقدة على خط السير وبطاقة تحمل رقم اليوم واسم
// المحطة وحالتها. مكتملة: زمردية بعلامة الإنجاز. نشطة: توهج كهرماني.
// مقفلة: رمادية بقفل زمني هادئ.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../domain/journey_snapshot.dart';
import 'station_labels.dart';

/// صف المحطة على المسار.
class StationNode extends StatelessWidget {
  const StationNode({
    super.key,
    required this.view,
    required this.today,
    required this.dayNumber,
    required this.centerX,
    required this.rowHeight,
    required this.nodeRadius,
    required this.width,
    required this.pulse,
    required this.onTap,
  });

  /// المحطة.
  final StationView view;

  /// حالة وِرد اليوم.
  final TodayKind today;

  /// رقم اليوم المعروض في عقدة المحطة النشطة.
  final int? dayNumber;

  /// مركز العقدة أفقياً.
  final double centerX;

  /// ارتفاع الصف.
  final double rowHeight;

  /// نصف قطر العقدة.
  final double nodeRadius;

  /// عرض المسار.
  final double width;

  /// نبض التوهج.
  final Animation<double> pulse;

  /// اللمس.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool nodeOnRight = centerX > width / 2;
    const double cardGap = 12;
    const double edge = 16;
    final String statusLine = stationStatusLine(view, today);
    final String semantic =
        'المحطة ${arabicDigits(view.station.order)}: ${view.station.name}، ${stationDaysLabel(view)}، $statusLine';

    return Semantics(
      button: true,
      label: semantic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: SizedBox(
            width: width,
            height: rowHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: centerX - nodeRadius,
                  top: rowHeight / 2 - nodeRadius,
                  width: nodeRadius * 2,
                  height: nodeRadius * 2,
                  child: _NodeCircle(
                    view: view,
                    dayNumber: dayNumber,
                    radius: nodeRadius,
                    pulse: pulse,
                  ),
                ),
                Positioned(
                  left: nodeOnRight ? edge : centerX + nodeRadius + cardGap,
                  right: nodeOnRight ? width - centerX + nodeRadius + cardGap : edge,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: nodeOnRight ? Alignment.centerRight : Alignment.centerLeft,
                    child: _StationCard(
                      view: view,
                      statusLine: statusLine,
                      palette: palette,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.view,
    required this.dayNumber,
    required this.radius,
    required this.pulse,
  });

  final StationView view;
  final int? dayNumber;
  final double radius;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    switch (view.status) {
      case StationStatus.completed:
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: palette.emeraldGradient,
            border: Border.all(color: palette.surface, width: 3),
          ),
          child: Icon(Icons.check_rounded, color: palette.onAccent, size: radius),
        );
      case StationStatus.active:
        return AnimatedBuilder(
          animation: pulse,
          builder: (BuildContext context, Widget? child) {
            final double wave = (math.sin(pulse.value * math.pi * 2) + 1) / 2;
            return DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: palette.amberGradient,
                border: Border.all(color: palette.surface, width: 3),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: palette.amber.withValues(alpha: 0.28 + 0.27 * wave),
                    blurRadius: 14 + 14 * wave,
                    spreadRadius: 2 + 6 * wave,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Center(
            child: Text(
              dayNumber == null ? arabicDigits(view.station.order) : arabicDigits(dayNumber!),
              style: text.titleLarge?.copyWith(
                color: palette.onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case StationStatus.locked:
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.lockedSoft,
            border: Border.all(color: palette.locked.withValues(alpha: 0.55), width: 2),
          ),
          child: Icon(
            view.lockReason == StationLockReason.awaitingDawn
                ? Icons.lock_clock
                : Icons.lock_rounded,
            color: palette.locked,
            size: radius * 0.8,
          ),
        );
    }
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.view,
    required this.statusLine,
    required this.palette,
  });

  final StationView view;
  final String statusLine;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool locked = view.status == StationStatus.locked;
    final bool active = view.status == StationStatus.active;
    final bool completed = view.status == StationStatus.completed;
    final Color statusColor = completed
        ? palette.emeraldText
        : active
            ? palette.amberText
            : palette.locked;
    final Color? border = active
        ? palette.amber
        : completed
            ? palette.emerald.withValues(alpha: 0.45)
            : palette.line;
    return SmoothSurface(
      color: locked ? palette.surfaceMuted : palette.surface,
      borderColor: border,
      borderWidth: active ? 1.6 : 1,
      radius: AppShapes.radiusMedium,
      elevated: active,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            stationDaysLabel(view),
            style: text.labelSmall?.copyWith(
              color: locked ? palette.locked : palette.amberText,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            view.station.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heritageTitle(
              color: locked ? palette.inkSoft : palette.ink,
              fontSize: 21,
            ),
          ),
          if (view.station.event != null)
            Text(
              view.station.event!.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: palette.inkSoft, height: 1.5),
            ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                completed
                    ? Icons.verified_outlined
                    : active
                        ? Icons.wb_twilight_rounded
                        : Icons.lock_clock,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  statusLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// رأس المرحلة على المسار.
class RegionHeader extends StatelessWidget {
  const RegionHeader({
    super.key,
    required this.ordinal,
    required this.name,
    required this.theme,
    required this.stationCount,
    required this.completedFraction,
    required this.locked,
  });

  /// ترتيب المرحلة بالكلمة.
  final String ordinal;

  /// الاسم.
  final String name;

  /// موضوع أحاديثها.
  final String theme;

  /// عدد محطاتها.
  final int stationCount;

  /// نسبة ما اكتمل منها.
  final double completedFraction;

  /// هل لم تبلغها القافلة بعد.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return SmoothSurface(
      elevated: !locked,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'المرحلة $ordinal · ${stationCountLabel(stationCount)}',
            style: text.labelSmall?.copyWith(
              color: palette.amberText,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heritageTitle(
              color: locked ? palette.inkSoft : palette.ink,
              fontSize: 23,
            ),
          ),
          Text(
            theme,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completedFraction.clamp(0.0, 1.0).toDouble(),
              minHeight: 5,
              color: palette.emerald,
              backgroundColor: palette.line,
            ),
          ),
        ],
      ),
    );
  }
}
