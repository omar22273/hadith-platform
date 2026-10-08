// هندسة المسار المتعرج: مواضع رؤوس المراحل والمحطات، ومنحنيات S بينها.
//
// الحساب حتمي من عرض الشاشة وحجم الخط، فيرسم الرسام والودجات المواضع نفسها.

import 'dart:ui' show Offset, Path, PathMetric, Rect, Tangent;

import 'package:flutter/foundation.dart';

import '../../domain/journey_snapshot.dart';

/// رأس مرحلة في المسار.
@immutable
class TrailHeaderBox {
  const TrailHeaderBox({
    required this.rect,
    required this.regionId,
    required this.firstStationIndex,
  });

  /// المستطيل.
  final Rect rect;

  /// المرحلة.
  final String regionId;

  /// أول محطة فيها.
  final int firstStationIndex;
}

/// تخطيط المسار.
@immutable
class TrailLayout {
  const TrailLayout._({
    required this.width,
    required this.height,
    required this.rowHeight,
    required this.headerHeight,
    required this.nodeRadius,
    required this.headers,
    required this.rowTops,
    required this.nodeCenters,
    required this.segments,
  });

  /// يحسب التخطيط. أول محطة على اليمين (بداية السطر العربي) ثم يتعرج المسار.
  factory TrailLayout.compute({
    required double width,
    required double textScale,
    required List<StationView> stations,
  }) {
    final double scale = textScale.clamp(1.0, 1.3).toDouble();
    final double rowHeight = 138 * scale;
    final double headerHeight = 116 * scale;
    const double nodeRadius = 30;
    const double top = 8;
    const double headerGap = 6;
    const double bottom = 120;
    const double sidePadding = 16;

    final List<TrailHeaderBox> headers = <TrailHeaderBox>[];
    final List<double> rowTops = <double>[];
    final List<Offset> centers = <Offset>[];
    double y = top;
    for (int k = 0; k < stations.length; k++) {
      final StationView view = stations[k];
      final bool newRegion = k == 0 || stations[k - 1].station.regionId != view.station.regionId;
      if (newRegion) {
        headers.add(
          TrailHeaderBox(
            rect: Rect.fromLTWH(sidePadding, y, width - sidePadding * 2, headerHeight),
            regionId: view.station.regionId,
            firstStationIndex: k,
          ),
        );
        y += headerHeight + headerGap;
      }
      rowTops.add(y);
      final double x = k.isEven ? width * 0.73 : width * 0.27;
      centers.add(Offset(x, y + rowHeight / 2));
      y += rowHeight;
    }

    final List<Path> segments = <Path>[];
    for (int k = 0; k + 1 < centers.length; k++) {
      final Offset a = centers[k];
      final Offset b = centers[k + 1];
      final double bend = (b.dy - a.dy) * 0.58;
      segments.add(
        Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(a.dx, a.dy + bend, b.dx, b.dy - bend, b.dx, b.dy),
      );
    }

    return TrailLayout._(
      width: width,
      height: y + bottom,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      nodeRadius: nodeRadius,
      headers: List<TrailHeaderBox>.unmodifiable(headers),
      rowTops: List<double>.unmodifiable(rowTops),
      nodeCenters: List<Offset>.unmodifiable(centers),
      segments: List<Path>.unmodifiable(segments),
    );
  }

  /// العرض.
  final double width;

  /// الارتفاع الكلي.
  final double height;

  /// ارتفاع صف المحطة.
  final double rowHeight;

  /// ارتفاع رأس المرحلة.
  final double headerHeight;

  /// نصف قطر عقدة المحطة.
  final double nodeRadius;

  /// رؤوس المراحل.
  final List<TrailHeaderBox> headers;

  /// أعلى صف كل محطة.
  final List<double> rowTops;

  /// مراكز العقد.
  final List<Offset> nodeCenters;

  /// المقطع k يصل المحطة k بالمحطة k + 1.
  final List<Path> segments;

  /// هل العقدة على يمين الشاشة.
  bool isRightSide(int stationIndex) => nodeCenters[stationIndex].dx > width / 2;

  /// نقطة على المقطع k عند النسبة t من طوله.
  Offset pointAlong(int segmentIndex, double t) {
    final Path path = segments[segmentIndex];
    for (final PathMetric metric in path.computeMetrics()) {
      final Tangent? tangent = metric.getTangentForOffset(metric.length * t.clamp(0.0, 1.0));
      if (tangent != null) {
        return tangent.position;
      }
    }
    return nodeCenters[segmentIndex];
  }
}
