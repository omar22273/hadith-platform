// الخريطة التفاعلية لرحلة السيرة: يابسة إقليم الحجاز والبحر الأحمر والحبشة،
// ومواضع المحطات بأعدادها، وخط السير بترتيب المحطات الزمني؛ المقطوع منه حتى
// المحطة المختارة كهرماني، والقادم نقاط هادئة. تُكبَّر الخريطة باللمس، وتبقى
// العلامات بحجمها.

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/seerah_station.dart';
import '../../domain/seerah_map.dart';

/// إسقاط متساوي المسافات مع تصحيح التمدد الأفقي عند منتصف العرض.
@immutable
class SeerahMapProjection {
  const SeerahMapProjection(this.bounds, this.width);

  /// حدود الخريطة.
  final GeoBounds bounds;

  /// عرض اللوحة.
  final double width;

  double get _cosLat => math.cos(bounds.midLatitude * math.pi / 180);

  double get _scale => width / ((bounds.maxLongitude - bounds.minLongitude) * _cosLat);

  /// ارتفاع اللوحة المقابل للعرض.
  double get height => (bounds.maxLatitude - bounds.minLatitude) * _scale;

  /// موضع النقطة على اللوحة.
  Offset project(GeoPoint point) {
    return Offset(
      (point.longitude - bounds.minLongitude) * _cosLat * _scale,
      (bounds.maxLatitude - point.latitude) * _scale,
    );
  }
}

/// الخريطة.
class SeerahMapView extends StatefulWidget {
  const SeerahMapView({
    super.key,
    required this.land,
    required this.route,
    required this.stations,
    required this.selectedIndex,
    required this.visited,
    required this.onClusterTap,
  });

  /// اليابسة.
  final SeerahLand land;

  /// المواضع وخط السير.
  final SeerahRoute route;

  /// المحطات بترتيبها الزمني.
  final List<SeerahStationModel> stations;

  /// ترتيب المحطة المختارة.
  final int selectedIndex;

  /// المحطات المكتملة مشاهدها.
  final Set<String> visited;

  /// لمس موضع.
  final ValueChanged<SeerahPlaceCluster> onClusterTap;

  @override
  State<SeerahMapView> createState() => _SeerahMapViewState();
}

class _SeerahMapViewState extends State<SeerahMapView> {
  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final SeerahMapProjection projection = SeerahMapProjection(
          widget.land.bounds,
          constraints.maxWidth,
        );
        final String selectedId = widget.stations.isEmpty ? '' : widget.stations[widget.selectedIndex].id;
        final int? selectedCluster = widget.route.clusterOfStation[selectedId];
        return SizedBox(
          width: projection.width,
          height: projection.height,
          child: ClipRect(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 6,
              child: SizedBox(
                width: projection.width,
                height: projection.height,
                child: AnimatedBuilder(
                  animation: _transform,
                  builder: (BuildContext context, Widget? child) {
                    final double zoom = _transform.value.getMaxScaleOnAxis();
                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _SeerahMapPainter(
                                land: widget.land,
                                route: widget.route,
                                projection: projection,
                                reachedStationIndex: widget.selectedIndex,
                                palette: palette,
                                zoom: zoom,
                              ),
                            ),
                          ),
                        ),
                        for (final SeerahPlaceCluster cluster in widget.route.clusters)
                          _positionedPin(
                            cluster: cluster,
                            projection: projection,
                            zoom: zoom,
                            selected: cluster.index == selectedCluster,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _positionedPin({
    required SeerahPlaceCluster cluster,
    required SeerahMapProjection projection,
    required double zoom,
    required bool selected,
  }) {
    const double box = 96;
    final Offset at = projection.project(cluster.center);
    final bool allVisited =
        cluster.stations.every((SeerahStationModel station) => widget.visited.contains(station.id));
    return Positioned(
      left: at.dx - box / 2,
      top: at.dy - 18,
      width: box,
      height: box,
      child: Transform.scale(
        scale: 1 / zoom,
        alignment: Alignment.topCenter,
        child: _ClusterPin(
          cluster: cluster,
          selected: selected,
          visited: allVisited,
          onTap: () => widget.onClusterTap(cluster),
        ),
      ),
    );
  }
}

class _ClusterPin extends StatelessWidget {
  const _ClusterPin({
    required this.cluster,
    required this.selected,
    required this.visited,
    required this.onTap,
  });

  final SeerahPlaceCluster cluster;
  final bool selected;
  final bool visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final int count = cluster.stations.length;
    return Semantics(
      button: true,
      selected: selected,
      label: '${cluster.name}: ${arabicDigits(count)} ${count == 1 ? 'محطة' : 'محطات'}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: selected ? 40 : 34,
                height: selected ? 40 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? palette.amberGradient : null,
                  color: selected ? null : palette.surface,
                  border: Border.all(
                    color: visited ? palette.emerald : (selected ? palette.surface : palette.amber),
                    width: visited ? 3 : 2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (selected ? palette.amber : palette.shadow).withValues(alpha: selected ? 0.5 : 0.35),
                      blurRadius: selected ? 16 : 8,
                      spreadRadius: selected ? 1 : -1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  arabicDigits(count),
                  style: AppTypography.ui(
                    color: selected ? palette.onAccent : palette.amberText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  child: Text(
                    cluster.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.ui(
                      color: palette.ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeerahMapPainter extends CustomPainter {
  _SeerahMapPainter({
    required this.land,
    required this.route,
    required this.projection,
    required this.reachedStationIndex,
    required this.palette,
    required this.zoom,
  });

  final SeerahLand land;
  final SeerahRoute route;
  final SeerahMapProjection projection;
  final int reachedStationIndex;
  final AppPalette palette;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect frame = Offset.zero & size;
    canvas.drawRect(frame, Paint()..color = palette.surfaceMuted);

    final Paint grid = Paint()
      ..color = palette.line.withValues(alpha: 0.7)
      ..strokeWidth = 0.6 / zoom;
    final GeoBounds bounds = land.bounds;
    for (double lon = (bounds.minLongitude / 5).ceil() * 5; lon <= bounds.maxLongitude; lon += 5) {
      final Offset top = projection.project(GeoPoint(bounds.maxLatitude, lon));
      final Offset bottom = projection.project(GeoPoint(bounds.minLatitude, lon));
      canvas.drawLine(top, bottom, grid);
    }
    for (double lat = (bounds.minLatitude / 5).ceil() * 5; lat <= bounds.maxLatitude; lat += 5) {
      final Offset left = projection.project(GeoPoint(lat, bounds.minLongitude));
      final Offset right = projection.project(GeoPoint(lat, bounds.maxLongitude));
      canvas.drawLine(left, right, grid);
    }

    final Path landPath = Path()..fillType = PathFillType.evenOdd;
    for (final List<GeoPoint> ring in land.rings) {
      final Offset first = projection.project(ring.first);
      landPath.moveTo(first.dx, first.dy);
      for (int i = 1; i < ring.length; i++) {
        final Offset point = projection.project(ring[i]);
        landPath.lineTo(point.dx, point.dy);
      }
      landPath.close();
    }
    canvas.drawPath(landPath, Paint()..color = palette.road);
    canvas.drawPath(
      landPath,
      Paint()
        ..color = palette.amber.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 / zoom,
    );

    _label(canvas, 'البحر الأحمر', const GeoPoint(19.6, 38.7), italic: true, angle: -1.03);
    _label(canvas, 'جزيرة العرب', const GeoPoint(23.6, 44.2), italic: false, angle: 0);
    _label(canvas, 'الحبشة', const GeoPoint(12.4, 37.6), italic: false, angle: 0);

    final Paint walked = Paint()
      ..color = palette.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 / zoom
      ..strokeCap = StrokeCap.round;
    final Paint ahead = Paint()
      ..color = palette.locked
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 / zoom
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < route.legs.length; i++) {
      final SeerahLeg leg = route.legs[i];
      final Offset a = projection.project(route.clusters[leg.from].center);
      final Offset b = projection.project(route.clusters[leg.to].center);
      final Offset mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final Offset delta = b - a;
      final double bend = i.isEven ? 0.22 : -0.22;
      final Offset control = mid + Offset(-delta.dy * bend, delta.dx * bend);
      final Path path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
      if (leg.arrivalStationIndex <= reachedStationIndex) {
        canvas.drawPath(path, walked);
      } else {
        _dotted(canvas, path, ahead);
      }
    }
  }

  void _dotted(Canvas canvas, Path path, Paint paint) {
    final double dot = 1 / zoom;
    final double gap = 8 / zoom;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = math.min(distance + dot, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  void _label(Canvas canvas, String text, GeoPoint at, {required bool italic, required double angle}) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.heritageTitle(
          color: palette.inkSoft.withValues(alpha: 0.75),
          fontSize: 13 / zoom,
        ).copyWith(fontStyle: italic ? FontStyle.italic : FontStyle.normal, letterSpacing: 0.6),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final Offset center = projection.project(at);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(_SeerahMapPainter oldDelegate) {
    return oldDelegate.land != land ||
        oldDelegate.route != route ||
        oldDelegate.projection.width != projection.width ||
        oldDelegate.reachedStationIndex != reachedStationIndex ||
        oldDelegate.palette != palette ||
        oldDelegate.zoom != zoom;
  }
}
