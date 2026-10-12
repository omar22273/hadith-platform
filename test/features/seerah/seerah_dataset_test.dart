// اختبارات بيانات رحلة السيرة: التحويل ذهاباً وإياباً، وسلامة المحطات مع
// فهرس المصادر، وشاهد لكل مشهد، وتجميع المواضع وخط السير، واليابسة.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/core/content/models/content_models.dart';
import 'package:hadith_platform/core/json/json_reader.dart';
import 'package:hadith_platform/features/seerah/data/models/seerah_station.dart';
import 'package:hadith_platform/features/seerah/domain/seerah_integrity.dart';
import 'package:hadith_platform/features/seerah/domain/seerah_map.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

void main() {
  final JsonMap raw = _load('assets/data/seerah_dataset.json');
  final SeerahDataset dataset = SeerahDataset.fromJson(raw);
  final SourceCatalog sources = SourceCatalog.fromJson(_load('assets/data/catalogs/sources.json'));

  test('round trip keeps the file byte-for-byte equivalent', () {
    expect(dataset.toJson(), equals(raw));
  });

  test('the dataset passes the integrity checks against the source catalog', () {
    expect(checkSeerahDataset(dataset, sources: sources), isEmpty);
  });

  test('the journey spans the Year of the Elephant to the Highest Companion', () {
    final List<SeerahStationModel> stations = dataset.chronological;
    expect(stations.first.epoch, SeerahEpoch.preMission);
    expect(stations.first.timeLabel, 'عام الفيل');
    expect(stations.last.epoch, SeerahEpoch.medinan);
    expect(stations.map((SeerahStationModel s) => s.epoch).toSet(), SeerahEpoch.values.toSet());
    for (int i = 1; i < stations.length; i++) {
      expect(stations[i].order, greaterThan(stations[i - 1].order));
    }
  });

  test('every scene is backed by a verbatim, located quote', () {
    for (final SeerahStationModel station in dataset.stations) {
      for (final SeerahScene scene in SeerahScene.values) {
        final List<SeerahEvidence> evidence = station.evidenceFor(scene);
        expect(evidence, isNotEmpty, reason: '${station.id} ${scene.wire}');
        for (final SeerahEvidence item in evidence) {
          expect(item.source.quote?.trim(), isNotEmpty);
          expect(item.source.locator?.trim(), isNotEmpty);
        }
      }
      expect(station.review.status, ReviewStatus.pendingScholarlyReview);
    }
  });

  test('a station missing the evidence of a scene is rejected', () {
    final SeerahStationModel first = dataset.chronological.first;
    final SeerahStationModel broken = SeerahStationModel.fromJson(<String, dynamic>{
      ...first.toJson(),
      'evidence': <dynamic>[
        for (final SeerahEvidence item in first.evidence)
          if (item.scene != SeerahScene.decision) item.toJson(),
      ],
    });
    final SeerahDataset tampered = SeerahDataset(
      schemaVersion: dataset.schemaVersion,
      id: dataset.id,
      title: dataset.title,
      stations: <SeerahStationModel>[broken],
    );
    expect(checkSeerahDataset(tampered, sources: sources), isNotEmpty);
  });

  test('only the station whose source states the alternatives carries dilemma options, verbatim', () {
    for (final SeerahStationModel station in dataset.stations) {
      final List<String>? options = station.dilemmaOptions;
      if (station.id != 'badr_hubab_counsel') {
        expect(options, isNull, reason: station.id);
        continue;
      }
      expect(options, hasLength(2));
      final List<String> quotes = <String>[
        for (final SeerahEvidence item in station.evidenceFor(SeerahScene.challenge)) item.source.quote!,
      ];
      for (final String option in options!) {
        expect(quotes.any((String q) => q.contains(option)), isTrue, reason: option);
      }
    }
  });

  group('the dilemma options integrity rule', () {
    SeerahDataset withOptions(List<String> options) {
      final SeerahStationModel badr = dataset.stationById('badr_hubab_counsel')!;
      return SeerahDataset(
        schemaVersion: dataset.schemaVersion,
        id: dataset.id,
        title: dataset.title,
        stations: <SeerahStationModel>[
          SeerahStationModel.fromJson(<String, dynamic>{...badr.toJson(), 'dilemma_options': options}),
        ],
      );
    }

    test('an option that is not in the challenge quotes is rejected', () {
      final List<String> issues = checkSeerahDataset(
        withOptions(<String>['الرأي والحرب والمكيدة', 'خيار لا أصل له في الشاهد']),
        sources: sources,
      );
      expect(issues, contains(contains('dilemma_options[1]')));
    });

    test('fewer than two options, or a repeated one, is rejected', () {
      expect(checkSeerahDataset(withOptions(<String>['الرأي والحرب والمكيدة']), sources: sources), contains(contains('two distinct')));
      expect(
        checkSeerahDataset(withOptions(<String>['الرأي والحرب والمكيدة', 'الرأي والحرب والمكيدة']), sources: sources),
        contains(contains('two distinct')),
      );
    });

    test('the schema allows the key but never requires it', () {
      final JsonMap schema = _load('assets/data/schema/hadith_platform.schema.json');
      final JsonMap station = asJsonMap(asJsonMap(schema['\$defs'], 'defs')['SeerahStationModel'], 'station');
      expect(asJsonMap(station['properties'], 'properties').containsKey('dilemma_options'), isTrue);
      expect(station['required'] as List<dynamic>, isNot(contains('dilemma_options')));
    });
  });

  test('stations cluster into places and the route follows their order', () {
    final SeerahRoute route = SeerahRoute.build(dataset.chronological);
    final List<String> names = route.clusters.map((SeerahPlaceCluster c) => c.name).toList();
    expect(names, contains('مكة'));
    expect(names, contains('أرض الحبشة'));
    expect(names, contains('المدينة النبوية'));
    expect(names, contains('بدر'));
    for (final SeerahStationModel station in dataset.stations) {
      expect(route.clusterOfStation[station.id], isNotNull, reason: station.id);
    }
    for (final SeerahLeg leg in route.legs) {
      expect(leg.from, isNot(leg.to));
    }
    expect(route.legs, isNotEmpty);
  });

  test('the land outline loads and contains every station', () {
    final SeerahLand land = SeerahLand.fromJson(_load('assets/data/seerah_map_land.json'));
    expect(land.rings, isNotEmpty);
    for (final SeerahStationModel station in dataset.stations) {
      expect(
        land.bounds.contains(GeoPoint(station.place.latitude, station.place.longitude)),
        isTrue,
        reason: station.id,
      );
    }
  });
}
