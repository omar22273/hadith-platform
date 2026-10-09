// مسار القوافل المتعرج لأوراد الأربعين: طريق S عمودي يرسمه CustomPainter،
// تعلوه رؤوس المجموعات وعقد الأحاديث ومجسم القافلة. عند تقدم القافلة تسير
// على المقطع الجديد حركةً، ويُلغى ذلك إن طلب المستخدم تقليل الحركة.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/journey_snapshot.dart';
import 'caravan_marker.dart';
import 'caravan_trail_painter.dart';
import 'trail_geometry.dart';
import 'wird_node.dart';

/// المسار.
class CaravanTrailView extends StatefulWidget {
  const CaravanTrailView({
    super.key,
    required this.snapshot,
    required this.onNodeTap,
  });

  /// اللقطة.
  final JourneySnapshot snapshot;

  /// فتح بطاقة عقدة بموضعها.
  final ValueChanged<int> onNodeTap;

  @override
  State<CaravanTrailView> createState() => _CaravanTrailViewState();
}

class _CaravanTrailViewState extends State<CaravanTrailView> with TickerProviderStateMixin {
  static const double _maxTextScale = 1.3;
  static const double _markerSize = 44;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: 1,
  );

  late final CurvedAnimation _travelCurve = CurvedAnimation(
    parent: _travel,
    curve: Curves.easeInOutCubic,
  );

  final GlobalKey _caravanRowKey = GlobalKey();
  int _travelSegment = -1;
  bool _initialScrollDone = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncPulse();
  }

  @override
  void didUpdateWidget(CaravanTrailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
    final int previous = oldWidget.snapshot.caravanIndex;
    final int current = widget.snapshot.caravanIndex;
    if (current == previous + 1 && !_reduceMotion) {
      _travelSegment = previous;
      _travel.forward(from: 0);
      _scheduleScrollToCaravan(animate: true);
    } else if (current != previous) {
      _travelSegment = -1;
      _travel.value = 1;
      _scheduleScrollToCaravan(animate: !_reduceMotion);
    }
  }

  void _syncPulse() {
    final bool hasToday = widget.snapshot.todayKind == TodayKind.available;
    if (hasToday && !_reduceMotion) {
      if (!_pulse.isAnimating) {
        _pulse.repeat();
      }
    } else {
      _pulse
        ..stop()
        ..value = 0.25;
    }
  }

  @override
  void dispose() {
    _travelCurve.dispose();
    _travel.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _scheduleScrollToCaravan({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      final BuildContext? rowContext = _caravanRowKey.currentContext;
      if (!mounted || rowContext == null) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.45,
          duration: animate ? const Duration(milliseconds: 700) : Duration.zero,
          curve: Curves.easeInOutCubic,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final double textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final double clampedScale = textScale > _maxTextScale ? _maxTextScale : textScale;
    if (!_initialScrollDone) {
      _initialScrollDone = true;
      _scheduleScrollToCaravan(animate: false);
    }
    final JourneySnapshot snapshot = widget.snapshot;
    final List<int> groups = <int>[
      for (final WirdNode node in snapshot.nodes) node.segmentIndex,
    ];
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TrailLayout layout = TrailLayout.compute(
            width: constraints.maxWidth,
            textScale: clampedScale,
            groupOfNode: groups,
          );
          final List<Widget> children = <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: CaravanTrailPainter(
                    layout: layout,
                    caravanIndex: snapshot.caravanIndex,
                    travelSegment: _travelSegment,
                    travel: _travelCurve,
                    palette: palette,
                  ),
                ),
              ),
            ),
          ];
          for (final TrailHeaderBox header in layout.headers) {
            final PathSegment segment = snapshot.segments[header.groupIndex];
            children.add(
              Positioned.fromRect(
                rect: header.rect,
                child: SegmentHeader(
                  segment: segment,
                  locked: header.firstNodeIndex > snapshot.caravanIndex,
                ),
              ),
            );
          }
          for (int k = 0; k < snapshot.nodes.length; k++) {
            children.add(
              Positioned(
                key: k == snapshot.caravanIndex ? _caravanRowKey : null,
                left: 0,
                top: layout.rowTops[k],
                width: layout.width,
                height: layout.rowHeight,
                child: WirdNodeView(
                  node: snapshot.nodes[k],
                  centerX: layout.nodeCenters[k].dx,
                  rowHeight: layout.rowHeight,
                  nodeRadius: layout.nodeRadius,
                  width: layout.width,
                  pulse: _pulse,
                  onTap: () => widget.onNodeTap(k),
                ),
              ),
            );
          }
          if (snapshot.nodes.isNotEmpty) {
            children.add(
              AnimatedBuilder(
                animation: _travelCurve,
                builder: (BuildContext context, Widget? child) {
                  final bool travelling = _travelSegment >= 0 && _travel.value < 1;
                  final Offset anchor = travelling
                      ? layout.pointAlong(_travelSegment, _travelCurve.value)
                      : layout.nodeCenters[snapshot.caravanIndex];
                  return Positioned(
                    left: anchor.dx - _markerSize / 2,
                    top: anchor.dy - layout.nodeRadius - _markerSize + 6,
                    width: _markerSize,
                    height: _markerSize,
                    child: IgnorePointer(child: child),
                  );
                },
                child: CaravanMarker(
                  size: _markerSize,
                  waiting: snapshot.todayKind == TodayKind.capReached,
                ),
              ),
            );
          }
          return SizedBox(
            width: layout.width,
            height: layout.height,
            child: Stack(clipBehavior: Clip.none, children: children),
          );
        },
      ),
    );
  }
}
