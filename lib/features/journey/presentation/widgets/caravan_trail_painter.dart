// رسام خط السير: طريق ترابي هادئ، والمقطوع منه بالزمردي، والقادم نقاط رمادية.
// أثناء سير القافلة يُرسم المقطع الجديد تدريجياً مع حركتها.

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import 'trail_geometry.dart';

/// رسام المسار المتعرج.
class CaravanTrailPainter extends CustomPainter {
  CaravanTrailPainter({
    required this.layout,
    required this.caravanIndex,
    required this.travelSegment,
    required this.travel,
    required this.palette,
  }) : super(repaint: travel);

  /// التخطيط.
  final TrailLayout layout;

  /// موضع القافلة.
  final int caravanIndex;

  /// المقطع الذي تسير عليه القافلة الآن، أو -1.
  final int travelSegment;

  /// تقدم السير على المقطع (0 - 1).
  final Animation<double> travel;

  /// الألوان.
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint road = Paint()
      ..color = palette.road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    final Paint walked = Paint()
      ..color = palette.emerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final Paint ahead = Paint()
      ..color = palette.locked
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (final Path segment in layout.segments) {
      canvas.drawPath(segment, road);
    }

    for (int k = 0; k < layout.segments.length; k++) {
      final Path segment = layout.segments[k];
      final bool reached = k + 1 <= caravanIndex;
      if (k == travelSegment && travel.value < 1) {
        _drawPartial(canvas, segment, walked, ahead, travel.value);
      } else if (reached) {
        canvas.drawPath(segment, walked);
      } else {
        _drawDotted(canvas, segment, ahead);
      }
    }
  }

  void _drawPartial(Canvas canvas, Path segment, Paint walked, Paint ahead, double t) {
    for (final PathMetric metric in segment.computeMetrics()) {
      final double split = metric.length * t;
      if (split > 0) {
        canvas.drawPath(metric.extractPath(0, split), walked);
      }
      final Path rest = metric.extractPath(split, metric.length);
      _drawDotted(canvas, rest, ahead);
    }
  }

  void _drawDotted(Canvas canvas, Path path, Paint paint) {
    const double dot = 1;
    const double gap = 12;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = math.min(distance + dot, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(CaravanTrailPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.caravanIndex != caravanIndex ||
        oldDelegate.travelSegment != travelSegment ||
        oldDelegate.palette != palette;
  }
}
