// هندسة المسار المتعرج: مواضع رؤوس المجموعات والعقد، ومنحنيات S بينها.
//
// الحساب حتمي من عرض الشاشة وحجم الخط، فيرسم الرسام والودجات المواضع نفسها.

import 'dart:ui' show Offset, Path, PathMetric, Rect, Tangent;

import 'package:flutter/foundation.dart';

/// صندوق رأس مجموعة.
@immutable
class TrailHeaderBox {
  const TrailHeaderBox({
    required this.rect,
    required this.groupIndex,
    required this.firstNodeIndex,
  });

  /// موضع الرأس.
  final Rect rect;

  /// رقم المجموعة.
  final int groupIndex;

  /// أول عقدة في المجموعة.
  final int firstNodeIndex;
}

/// فاصل قسمين يُراد إدراجه قبل عقدة بعينها، بارتفاعه.
@immutable
class TrailDividerSpec {
  const TrailDividerSpec({required this.dividerIndex, required this.beforeNodeIndex, required this.height});

  /// رقم الفاصل.
  final int dividerIndex;

  /// العقدة التي يسبقها الفاصل مباشرة.
  final int beforeNodeIndex;

  /// ارتفاع الفاصل.
  final double height;
}

/// صندوق فاصل قسمين.
@immutable
class TrailDividerBox {
  const TrailDividerBox({required this.rect, required this.dividerIndex, required this.beforeNodeIndex});

  /// موضع الفاصل.
  final Rect rect;

  /// رقم الفاصل.
  final int dividerIndex;

  /// العقدة التي يسبقها.
  final int beforeNodeIndex;
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
    required this.dividers,
    required this.rowTops,
    required this.nodeCenters,
    required this.segments,
  });

  /// يحسب التخطيط. [groupOfNode] رقم مجموعة كل عقدة بترتيبها، ويوضع رأس
  /// مجموعة قبل أول عقدة منها. [dividers] فواصل الأقسام: يُدرج كل منها بكامل
  /// العرض قبل عقدته. [tallHeaderGroups] المجموعات التي يحمل رأسها عنواناً فرعياً
  /// فيزيد ارتفاعه سطراً.
  factory TrailLayout.compute({
    required double width,
    required double textScale,
    required List<int> groupOfNode,
    List<TrailDividerSpec> dividers = const <TrailDividerSpec>[],
    Set<int> tallHeaderGroups = const <int>{},
  }) {
    final double scale = textScale < 1 ? 1 : (textScale > 1.3 ? 1.3 : textScale);
    final double rowHeight = 120 * scale;
    final double headerHeight = 104 * scale;
    const double nodeRadius = 28;
    const double top = 8;
    const double headerGap = 6;
    const double bottom = 120;
    const double sidePadding = 16;
    const double subtitleExtra = 30;

    final List<TrailHeaderBox> headers = <TrailHeaderBox>[];
    final List<TrailDividerBox> dividerBoxes = <TrailDividerBox>[];
    final List<double> rowTops = <double>[];
    final List<Offset> centers = <Offset>[];
    double y = top;
    for (int k = 0; k < groupOfNode.length; k++) {
      for (final TrailDividerSpec divider in dividers) {
        if (divider.beforeNodeIndex == k) {
          dividerBoxes.add(
            TrailDividerBox(
              rect: Rect.fromLTWH(sidePadding, y, width - sidePadding * 2, divider.height),
              dividerIndex: divider.dividerIndex,
              beforeNodeIndex: k,
            ),
          );
          y += divider.height + headerGap;
        }
      }
      final bool newGroup = k == 0 || groupOfNode[k - 1] != groupOfNode[k];
      if (newGroup) {
        final double height =
            tallHeaderGroups.contains(groupOfNode[k]) ? headerHeight + subtitleExtra * scale : headerHeight;
        headers.add(
          TrailHeaderBox(
            rect: Rect.fromLTWH(sidePadding, y, width - sidePadding * 2, height),
            groupIndex: groupOfNode[k],
            firstNodeIndex: k,
          ),
        );
        y += height + headerGap;
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
      dividers: List<TrailDividerBox>.unmodifiable(dividerBoxes),
      rowTops: List<double>.unmodifiable(rowTops),
      nodeCenters: List<Offset>.unmodifiable(centers),
      segments: List<Path>.unmodifiable(segments),
    );
  }

  /// عرض المسار.
  final double width;

  /// الارتفاع الكلي.
  final double height;

  /// ارتفاع صف العقدة.
  final double rowHeight;

  /// ارتفاع رأس المجموعة.
  final double headerHeight;

  /// نصف قطر العقدة.
  final double nodeRadius;

  /// رؤوس المجموعات.
  final List<TrailHeaderBox> headers;

  /// فواصل الأقسام.
  final List<TrailDividerBox> dividers;

  /// أعلى كل صف عقدة.
  final List<double> rowTops;

  /// مراكز العقد.
  final List<Offset> nodeCenters;

  /// منحنيات المسار بين كل عقدتين متتاليتين.
  final List<Path> segments;

  /// هل العقدة في يمين المسار.
  bool isRightSide(int nodeIndex) => nodeCenters[nodeIndex].dx > width / 2;

  /// نقطة على منحنى بنسبة t، لحركة القافلة.
  Offset pointAlong(int segmentIndex, double t) {
    final Path path = segments[segmentIndex];
    final double clamped = t < 0 ? 0 : (t > 1 ? 1 : t);
    for (final PathMetric metric in path.computeMetrics()) {
      final Tangent? tangent = metric.getTangentForOffset(metric.length * clamped);
      if (tangent != null) {
        return tangent.position;
      }
    }
    return nodeCenters[segmentIndex];
  }
}
