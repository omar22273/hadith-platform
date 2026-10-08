// مسار القوافل المتعرج: طريق S عمودي يرسمه CustomPainter، تعلوه رؤوس المراحل
// وكتل المحطات ومجسم القافلة. عند تقدم القافلة تسير على المقطع الجديد حركةً.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/journey_snapshot.dart';
import 'caravan_marker.dart';
import 'caravan_trail_painter.dart';
import 'station_labels.dart';
import 'station_node.dart';
import 'trail_geometry.dart';

/// عرض المسار. ارتفاعه ثابت محسوب، ويوضع داخل قائمة تمرير الشاشة.
class CaravanTrailView extends StatefulWidget {
  const CaravanTrailView({
    super.key,
    required this.snapshot,
    required this.onStationTap,
  });

  /// لقطة المسار.
  final JourneySnapshot snapshot;

  /// لمس محطة.
  final ValueChanged<int> onStationTap;

  @override
  State<CaravanTrailView> createState() => _CaravanTrailViewState();
}

class _CaravanTrailViewState extends State<CaravanTrailView> with TickerProviderStateMixin {
  static const double _maxTextScale = 1.3;
  static const double _markerSize = 46;

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

  /// التوهج يعمل فقط حين توجد محطة نشطة، ويتوقف عند تقليل الحركة.
  void _syncPulse() {
    final bool hasActive = widget.snapshot.stations.any(
      (StationView view) => view.status == StationStatus.active,
    );
    if (hasActive && !_reduceMotion) {
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
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
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

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TrailLayout layout = TrailLayout.compute(
            width: constraints.maxWidth,
            textScale: clampedScale,
            stations: snapshot.stations,
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

          for (int h = 0; h < layout.headers.length; h++) {
            final TrailHeaderBox header = layout.headers[h];
            final List<StationView> inRegion = snapshot.stations
                .where((StationView view) => view.station.regionId == header.regionId)
                .toList();
            final double done = inRegion.fold<double>(0, (double sum, StationView view) {
              if (view.wirds.isEmpty) {
                return sum + (view.status == StationStatus.completed ? 1 : 0);
              }
              return sum + view.completedCount / view.wirds.length;
            });
            final StationView first = snapshot.stations[header.firstStationIndex];
            children.add(
              Positioned.fromRect(
                rect: header.rect,
                child: RegionHeader(
                  ordinal: regionOrdinal(h),
                  name: first.region.name,
                  theme: first.region.theme,
                  stationCount: inRegion.length,
                  completedFraction: inRegion.isEmpty ? 0 : done / inRegion.length,
                  locked: header.firstStationIndex > snapshot.caravanIndex,
                ),
              ),
            );
          }

          for (int k = 0; k < snapshot.stations.length; k++) {
            final StationView view = snapshot.stations[k];
            children.add(
              Positioned(
                key: k == snapshot.caravanIndex ? _caravanRowKey : null,
                left: 0,
                top: layout.rowTops[k],
                width: layout.width,
                height: layout.rowHeight,
                child: StationNode(
                  view: view,
                  today: snapshot.todayKind,
                  dayNumber: view.status == StationStatus.active ? snapshot.nextDayNumber : null,
                  centerX: layout.nodeCenters[k].dx,
                  rowHeight: layout.rowHeight,
                  nodeRadius: layout.nodeRadius,
                  width: layout.width,
                  pulse: _pulse,
                  onTap: () => widget.onStationTap(k),
                ),
              ),
            );
          }

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
