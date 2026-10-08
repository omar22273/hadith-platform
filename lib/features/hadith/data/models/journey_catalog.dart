// فهرس مسار القوافل.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

import '../../../../core/json/json_reader.dart';
import 'source_ref.dart';

/// فهرس مسار القوافل.
@immutable
class JourneyCatalog {
  const JourneyCatalog({
    required this.schemaVersion,
    required this.regions,
    required this.stations,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory JourneyCatalog.fromJson(JsonMap json) {
    return JourneyCatalog(
      schemaVersion: readString(json, 'schemaVersion'),
      regions: readModelList(json, 'regions', JourneyRegion.fromJson),
      stations: readModelList(json, 'stations', JourneyStation.fromJson),
    );
  }

  /// إصدار المخطط.
  final String schemaVersion;

  /// المراحل الكبرى.
  final List<JourneyRegion> regions;

  /// المحطات.
  final List<JourneyStation> stations;

  /// يعيد المحطة بمعرّفها، أو null إن لم توجد.
  JourneyStation? stationById(String stationId) {
    for (final JourneyStation station in stations) {
      if (station.id == stationId) {
        return station;
      }
    }
    return null;
  }

  /// يعيد المرحلة بمعرّفها، أو null إن لم توجد.
  JourneyRegion? regionById(String regionId) {
    for (final JourneyRegion region in regions) {
      if (region.id == regionId) {
        return region;
      }
    }
    return null;
  }

  /// محطات مرحلة واحدة مرتبة حسب مسار الرحلة.
  List<JourneyStation> stationsInRegion(String regionId) {
    final List<JourneyStation> result = stations
        .where((JourneyStation station) => station.regionId == regionId)
        .toList()
      ..sort(
        (JourneyStation a, JourneyStation b) => a.order.compareTo(b.order),
      );
    return List<JourneyStation>.unmodifiable(result);
  }

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'regions': regions.map((JourneyRegion item) => item.toJson()).toList(),
      'stations': stations.map((JourneyStation item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is JourneyCatalog &&
        schemaVersion == other.schemaVersion &&
        listEquals(regions, other.regions) &&
        listEquals(stations, other.stations);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      schemaVersion,
      Object.hashAll(regions),
      Object.hashAll(stations),
    ]);
  }
}

/// مرحلة كبرى من الرحلة.
@immutable
class JourneyRegion {
  const JourneyRegion({
    required this.id,
    required this.order,
    required this.name,
    required this.theme,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory JourneyRegion.fromJson(JsonMap json) {
    return JourneyRegion(
      id: readString(json, 'id'),
      order: readInt(json, 'order'),
      name: readString(json, 'name'),
      theme: readString(json, 'theme'),
    );
  }

  /// المعرّف.
  final String id;

  /// الترتيب.
  final int order;

  /// الاسم.
  final String name;

  /// موضوع أحاديثها.
  final String theme;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'order': order,
      'name': name,
      'theme': theme,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is JourneyRegion &&
        id == other.id &&
        order == other.order &&
        name == other.name &&
        theme == other.theme;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      id,
      order,
      name,
      theme,
    ]);
  }
}

/// محطة على الخريطة.
@immutable
class JourneyStation {
  const JourneyStation({
    required this.id,
    required this.regionId,
    required this.order,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.coordinatesApproximate,
    required this.event,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory JourneyStation.fromJson(JsonMap json) {
    return JourneyStation(
      id: readString(json, 'id'),
      regionId: readString(json, 'regionId'),
      order: readInt(json, 'order'),
      name: readString(json, 'name'),
      description: readString(json, 'description'),
      latitude: readDouble(json, 'latitude'),
      longitude: readDouble(json, 'longitude'),
      coordinatesApproximate: readBool(json, 'coordinatesApproximate'),
      event: readModelOrNull(json, 'event', StationEvent.fromJson),
    );
  }

  /// المعرّف.
  final String id;

  /// المرحلة.
  final String regionId;

  /// الترتيب داخل الرحلة كلها.
  final int order;

  /// الاسم.
  final String name;

  /// وصف قصير.
  final String description;

  /// خط العرض.
  final double latitude;

  /// خط الطول.
  final double longitude;

  /// هل الإحداثيات تقريبية.
  final bool coordinatesApproximate;

  /// الحدث التاريخي الموثق للمحطة.
  final StationEvent? event;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'regionId': regionId,
      'order': order,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'coordinatesApproximate': coordinatesApproximate,
      'event': event?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is JourneyStation &&
        id == other.id &&
        regionId == other.regionId &&
        order == other.order &&
        name == other.name &&
        description == other.description &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        coordinatesApproximate == other.coordinatesApproximate &&
        event == other.event;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      id,
      regionId,
      order,
      name,
      description,
      latitude,
      longitude,
      coordinatesApproximate,
      event,
    ]);
  }
}

/// حدث تاريخي موثق بنصوص مصادره.
@immutable
class StationEvent {
  const StationEvent({
    required this.title,
    required this.sources,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory StationEvent.fromJson(JsonMap json) {
    return StationEvent(
      title: readString(json, 'title'),
      sources: readModelList(json, 'sources', SourceRef.fromJson),
    );
  }

  /// عنوان الحدث كما يُعرض على الخريطة، مستخلص من نصوص الشواهد.
  final String title;

  /// شواهد الحدث منقولة بنصها مع مواضعها.
  final List<SourceRef> sources;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'title': title,
      'sources': sources.map((SourceRef item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is StationEvent &&
        title == other.title &&
        listEquals(sources, other.sources);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      title,
      Object.hashAll(sources),
    ]);
  }
}
