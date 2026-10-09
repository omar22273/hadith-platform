// خريطة رحلة السيرة: اليابسة من Natural Earth (ملكية عامة) مقصوصة على إقليم
// الرحلة، وتجميع المحطات المتقاربة في مواضع، وخط السير بين المواضع بترتيب
// المحطات الزمني.

import 'package:flutter/foundation.dart';

import '../../../core/json/json_reader.dart';
import '../data/models/seerah_station.dart';

/// نقطة جغرافية.
@immutable
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  /// خط العرض.
  final double latitude;

  /// خط الطول.
  final double longitude;

  @override
  bool operator ==(Object other) {
    return other is GeoPoint && other.latitude == latitude && other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// حدود الخريطة.
@immutable
class GeoBounds {
  const GeoBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  /// أدنى خط عرض.
  final double minLatitude;

  /// أعلى خط عرض.
  final double maxLatitude;

  /// أدنى خط طول.
  final double minLongitude;

  /// أعلى خط طول.
  final double maxLongitude;

  /// منتصف خط العرض، لتصحيح التمدد الأفقي في الإسقاط.
  double get midLatitude => (minLatitude + maxLatitude) / 2;

  /// هل النقطة داخل الحدود.
  bool contains(GeoPoint point) {
    return point.latitude >= minLatitude &&
        point.latitude <= maxLatitude &&
        point.longitude >= minLongitude &&
        point.longitude <= maxLongitude;
  }
}

/// اليابسة المرسومة.
@immutable
class SeerahLand {
  const SeerahLand({required this.bounds, required this.rings, required this.source});

  /// يقرأ ملف اليابسة: {bounds, rings: [[[lon, lat], ...], ...], source}.
  factory SeerahLand.fromJson(JsonMap json) {
    final JsonMap bounds = readModel(json, 'bounds', (JsonMap value) => value);
    final Object? rawRings = json['rings'];
    if (rawRings is! List) {
      throw const JsonParseException('rings must be a list.');
    }
    final List<List<GeoPoint>> rings = <List<GeoPoint>>[];
    for (final Object? ring in rawRings) {
      if (ring is! List) {
        throw const JsonParseException('Each ring must be a list of points.');
      }
      final List<GeoPoint> points = <GeoPoint>[];
      for (final Object? point in ring) {
        if (point is! List || point.length != 2 || point[0] is! num || point[1] is! num) {
          throw const JsonParseException('Each point must be [longitude, latitude].');
        }
        points.add(GeoPoint((point[1] as num).toDouble(), (point[0] as num).toDouble()));
      }
      if (points.length >= 3) {
        rings.add(List<GeoPoint>.unmodifiable(points));
      }
    }
    return SeerahLand(
      bounds: GeoBounds(
        minLatitude: readDouble(bounds, 'minLatitude'),
        maxLatitude: readDouble(bounds, 'maxLatitude'),
        minLongitude: readDouble(bounds, 'minLongitude'),
        maxLongitude: readDouble(bounds, 'maxLongitude'),
      ),
      rings: List<List<GeoPoint>>.unmodifiable(rings),
      source: readString(json, 'source'),
    );
  }

  /// الحدود.
  final GeoBounds bounds;

  /// حلقات اليابسة.
  final List<List<GeoPoint>> rings;

  /// مصدر البيانات الجغرافية.
  final String source;
}

/// موضع على الخريطة يجمع محطات متقاربة.
@immutable
class SeerahPlaceCluster {
  const SeerahPlaceCluster({
    required this.index,
    required this.name,
    required this.center,
    required this.stations,
  });

  /// رقم الموضع.
  final int index;

  /// الاسم المعروض.
  final String name;

  /// الموضع.
  final GeoPoint center;

  /// محطاته بترتيبها الزمني.
  final List<SeerahStationModel> stations;

  /// هل تقع المحطة في هذا الموضع.
  bool holds(String stationId) {
    return stations.any((SeerahStationModel station) => station.id == stationId);
  }
}

/// تخطيط الرحلة: المواضع وخط السير.
@immutable
class SeerahRoute {
  const SeerahRoute._({
    required this.clusters,
    required this.clusterOfStation,
    required this.legs,
  });

  /// يجمع المحطات المتقاربة (ضمن [radiusDegrees]) في مواضع، ويبني خط السير.
  factory SeerahRoute.build(
    List<SeerahStationModel> chronological, {
    double radiusDegrees = 0.35,
  }) {
    final List<_ClusterDraft> drafts = <_ClusterDraft>[];
    final Map<String, int> clusterOf = <String, int>{};
    for (final SeerahStationModel station in chronological) {
      final GeoPoint point = GeoPoint(station.place.latitude, station.place.longitude);
      int? found;
      for (int i = 0; i < drafts.length; i++) {
        final GeoPoint anchor = drafts[i].anchor;
        if ((anchor.latitude - point.latitude).abs() <= radiusDegrees &&
            (anchor.longitude - point.longitude).abs() <= radiusDegrees) {
          found = i;
          break;
        }
      }
      if (found == null) {
        drafts.add(_ClusterDraft(anchor: point, name: _placeLabel(station.place.name)));
        found = drafts.length - 1;
      }
      drafts[found].stations.add(station);
      clusterOf[station.id] = found;
    }

    final List<SeerahPlaceCluster> clusters = <SeerahPlaceCluster>[
      for (int i = 0; i < drafts.length; i++)
        SeerahPlaceCluster(
          index: i,
          name: drafts[i].name,
          center: drafts[i].anchor,
          stations: List<SeerahStationModel>.unmodifiable(drafts[i].stations),
        ),
    ];

    final List<SeerahLeg> legs = <SeerahLeg>[];
    int? previousCluster;
    for (int s = 0; s < chronological.length; s++) {
      final int cluster = clusterOf[chronological[s].id]!;
      if (previousCluster != null && cluster != previousCluster) {
        legs.add(SeerahLeg(from: previousCluster, to: cluster, arrivalStationIndex: s));
      }
      previousCluster = cluster;
    }

    return SeerahRoute._(
      clusters: List<SeerahPlaceCluster>.unmodifiable(clusters),
      clusterOfStation: Map<String, int>.unmodifiable(clusterOf),
      legs: List<SeerahLeg>.unmodifiable(legs),
    );
  }

  /// المواضع.
  final List<SeerahPlaceCluster> clusters;

  /// موضع كل محطة بمعرّفها.
  final Map<String, int> clusterOfStation;

  /// مقاطع خط السير بين المواضع.
  final List<SeerahLeg> legs;

  /// اسم الموضع قبل النقطتين: «المدينة النبوية: موضع المسجد» ← «المدينة النبوية».
  static String _placeLabel(String name) {
    final int colon = name.indexOf(':');
    return colon < 0 ? name.trim() : name.substring(0, colon).trim();
  }
}

/// مقطع من خط السير.
@immutable
class SeerahLeg {
  const SeerahLeg({
    required this.from,
    required this.to,
    required this.arrivalStationIndex,
  });

  /// موضع الانطلاق.
  final int from;

  /// موضع الوصول.
  final int to;

  /// ترتيب المحطة (من صفر) التي يُبلغ بها موضع الوصول.
  final int arrivalStationIndex;
}

class _ClusterDraft {
  _ClusterDraft({required this.anchor, required this.name});

  final GeoPoint anchor;
  final String name;
  final List<SeerahStationModel> stations = <SeerahStationModel>[];
}
