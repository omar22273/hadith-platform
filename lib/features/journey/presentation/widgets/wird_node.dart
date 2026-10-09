// عقدة الوِرد التفاعلية: دائرة على خط السير وبطاقة تحمل رقم الحديث وعنوانه
// وحالته. مكتملة: زمردية بعلامة الإنجاز. نشطة: توهج كهرماني. مقفلة: رمادية.
// ورأس المجموعة: «العشرة الأولى» ونطاق أرقامها وتقدمها.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/app_shapes.dart';
import '../../../../core/ui/smooth_surface.dart';
import '../../domain/journey_snapshot.dart';
import 'wird_labels.dart';

/// عقدة الوِرد مع بطاقتها.
class WirdNodeView extends StatelessWidget {
  const WirdNodeView({
    super.key,
    required this.node,
    required this.centerX,
    required this.rowHeight,
    required this.nodeRadius,
    required this.width,
    required this.pulse,
    required this.onTap,
  });

  /// العقدة.
  final WirdNode node;

  /// مركز الدائرة أفقياً.
  final double centerX;

  /// ارتفاع الصف.
  final double rowHeight;

  /// نصف قطر الدائرة.
  final double nodeRadius;

  /// عرض المسار.
  final double width;

  /// نبض العقدة النشطة.
  final Animation<double> pulse;

  /// فتح بطاقة الوِرد.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool nodeOnRight = centerX > width / 2;
    const double cardGap = 12;
    const double edge = 16;
    return Semantics(
      button: true,
      label: wirdSemanticLabel(node),
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
                  child: _NodeCircle(node: node, radius: nodeRadius, pulse: pulse),
                ),
                Positioned(
                  left: nodeOnRight ? edge : centerX + nodeRadius + cardGap,
                  right: nodeOnRight ? width - centerX + nodeRadius + cardGap : edge,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: nodeOnRight ? Alignment.centerRight : Alignment.centerLeft,
                    child: _WirdCard(node: node),
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
  const _NodeCircle({required this.node, required this.radius, required this.pulse});

  final WirdNode node;
  final double radius;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    switch (node.status) {
      case WirdNodeStatus.completed:
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: palette.emeraldGradient,
            border: Border.all(color: palette.surface, width: 3),
          ),
          child: Icon(Icons.check_rounded, color: palette.onAccent, size: radius),
        );
      case WirdNodeStatus.today:
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
              arabicDigits(node.number),
              style: text.titleLarge?.copyWith(
                color: palette.onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case WirdNodeStatus.afterDawn:
      case WirdNodeStatus.upcoming:
      case WirdNodeStatus.inPreparation:
        {
          final bool dawn = node.status == WirdNodeStatus.afterDawn;
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.lockedSoft,
              border: Border.all(
                color: dawn ? palette.amber.withValues(alpha: 0.6) : palette.locked.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
            child: node.status == WirdNodeStatus.upcoming
                ? Center(
                    child: Text(
                      arabicDigits(node.number),
                      style: text.titleMedium?.copyWith(
                        color: palette.locked,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Icon(
                    dawn ? Icons.lock_clock : Icons.hourglass_empty_rounded,
                    color: dawn ? palette.amberText : palette.locked,
                    size: radius * 0.8,
                  ),
          );
        }
    }
  }
}

class _WirdCard extends StatelessWidget {
  const _WirdCard({required this.node});

  final WirdNode node;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool completed = node.status == WirdNodeStatus.completed;
    final bool today = node.status == WirdNodeStatus.today;
    final bool dawn = node.status == WirdNodeStatus.afterDawn;
    final bool muted = !completed && !today && !dawn;
    final Color statusColor = completed
        ? palette.emeraldText
        : today || dawn
            ? palette.amberText
            : palette.locked;
    final Color border = today
        ? palette.amber
        : completed
            ? palette.emerald.withValues(alpha: 0.45)
            : palette.line;
    final IconData statusIcon = switch (node.status) {
      WirdNodeStatus.completed => Icons.verified_outlined,
      WirdNodeStatus.today => Icons.wb_twilight_rounded,
      WirdNodeStatus.afterDawn => Icons.lock_clock,
      WirdNodeStatus.upcoming => Icons.lock_outline_rounded,
      WirdNodeStatus.inPreparation => Icons.hourglass_empty_rounded,
    };
    return SmoothSurface(
      color: muted ? palette.surfaceMuted : palette.surface,
      borderColor: border,
      borderWidth: today ? 1.6 : 1,
      radius: AppShapes.radiusMedium,
      elevated: today,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 9, 14, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            wirdNumberLabel(node),
            style: text.labelSmall?.copyWith(
              color: muted ? palette.locked : palette.amberText,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            wirdTitle(node),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heritageTitle(
              color: muted ? palette.inkSoft : palette.ink,
              fontSize: node.prepared ? 20 : 17,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  wirdStatusLine(node),
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

/// رأس مجموعة من عشرة أحاديث.
class SegmentHeader extends StatelessWidget {
  const SegmentHeader({super.key, required this.segment, required this.locked});

  /// المجموعة.
  final PathSegment segment;

  /// هل لم تبلغها القافلة بعد.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      label: '${segment.title}، ${segment.rangeLabel}، '
          'المكتمل ${arabicDigits(segment.completed)} من ${arabicDigits(segment.total)}',
      child: ExcludeSemantics(
        child: SmoothSurface(
          elevated: !locked,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                segment.rangeLabel,
                style: text.labelSmall?.copyWith(
                  color: palette.amberText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                segment.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heritageTitle(
                  color: locked ? palette.inkSoft : palette.ink,
                  fontSize: 23,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: segment.fraction,
                  minHeight: 5,
                  color: palette.emerald,
                  backgroundColor: palette.line,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
