// اختبارات بيانات رحلة السيرة: التحويل ذهاباً وإياباً، وسلامة الأطوار والمحطات
// والبوصلة والروابط والفصول مع فهرس المصادر، وشاهد لكل مشهد، وتجميع المواضع وخط
// السير، واليابسة.

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

  List<String> issuesOf(SeerahDataset candidate) => checkSeerahDataset(candidate, sources: sources);

  /// الملف نفسه وقد بُدّلت محطة واحدة بما يعدّله [edit] في خريطتها.
  SeerahDataset editStation(String id, void Function(JsonMap json) edit) {
    return SeerahDataset(
      schemaVersion: dataset.schemaVersion,
      id: dataset.id,
      title: dataset.title,
      epochs: dataset.epochs,
      stations: <SeerahStationModel>[
        for (final SeerahStationModel station in dataset.stations)
          if (station.id == id)
            SeerahStationModel.fromJson(() {
              final JsonMap json = Map<String, dynamic>.of(station.toJson());
              edit(json);
              return json;
            }())
          else
            station,
      ],
    );
  }

  /// الملف نفسه وقد بُدّلت أطواره.
  SeerahDataset withEpochs(List<SeerahEpochInfo> epochs) {
    return SeerahDataset(
      schemaVersion: dataset.schemaVersion,
      id: dataset.id,
      title: dataset.title,
      epochs: epochs,
      stations: dataset.stations,
    );
  }

  test('round trip keeps the file byte-for-byte equivalent', () {
    expect(dataset.toJson(), equals(raw));
  });

  test('the dataset passes the integrity checks against the source catalog', () {
    expect(issuesOf(dataset), isEmpty);
  });

  group('the epochs', () {
    test('are the ten major epochs in the asked order', () {
      expect(dataset.epochsInOrder.map((SeerahEpochInfo e) => e.number), <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(dataset.epochsInOrder.map((SeerahEpochInfo e) => e.title), <String>[
        'إرهاصات النبوة وعام الفيل',
        'النشأة والشباب قبل البعثة',
        'البعثة والدعوة السرية',
        'الجهر بالدعوة والصبر على الأذى',
        'الهجرة إلى الحبشة وعام الحزن',
        'بيعة العقبة والهجرة إلى المدينة',
        'تأسيس الدولة وبدر وأحد',
        'الخندق والحديبية وخيبر',
        'فتح مكة وحنين وتبوك',
        'حجة الوداع والرفيق الأعلى',
      ]);
    });

    test('every station belongs to a known epoch and the stations never step back an epoch', () {
      int previous = 0;
      for (final SeerahStationModel station in dataset.chronological) {
        final SeerahEpochInfo? epoch = dataset.epochOf(station);
        expect(epoch, isNotNull, reason: station.id);
        expect(epoch!.number, greaterThanOrEqualTo(previous), reason: station.id);
        previous = epoch.number;
      }
      expect(dataset.stationsOfEpoch('epoch_02_youth').map((SeerahStationModel s) => s.id), <String>[
        'hilf_al_fudul',
        'kaaba_black_stone',
      ]);
    });

    test('the epochs that await the full book are declared and empty, not invented', () {
      expect(dataset.stationsOfEpoch('epoch_04_public_call'), isEmpty);
      expect(dataset.stationsOfEpoch('epoch_08_khandaq_hudaybiyyah'), isEmpty);
      expect(dataset.epochById('epoch_04_public_call'), isNotNull);
      expect(dataset.epochById('not_an_epoch'), isNull);
    });

    test('a count outside eight to ten, a repeated id, or a repeated number is rejected', () {
      expect(issuesOf(withEpochs(dataset.epochs.take(3).toList())), contains(contains('Expected 8 to 10 epochs')));
      final List<SeerahEpochInfo> repeatedId = <SeerahEpochInfo>[
        ...dataset.epochs.take(9),
        SeerahEpochInfo(id: dataset.epochs.first.id, number: 10, title: 'مكرر'),
      ];
      expect(issuesOf(withEpochs(repeatedId)), contains(contains('Duplicate epoch id')));
      final List<SeerahEpochInfo> repeatedNumber = <SeerahEpochInfo>[
        ...dataset.epochs.take(9),
        const SeerahEpochInfo(id: 'epoch_x', number: 9, title: 'مكرر'),
      ];
      expect(issuesOf(withEpochs(repeatedNumber)), contains(contains('Duplicate epoch number')));
    });

    test('a station pointing at an unknown epoch, or one that precedes its predecessor, is rejected', () {
      expect(
        issuesOf(editStation('hilf_al_fudul', (JsonMap json) => json['epoch_id'] = 'epoch_99')),
        contains(contains('Unknown epoch "epoch_99"')),
      );
      expect(
        issuesOf(editStation('kaaba_black_stone', (JsonMap json) => json['epoch_id'] = 'epoch_01_omens')),
        contains(contains('precedes the epoch of the previous station')),
      );
    });
  });

  test('the journey spans the Year of the Elephant to the Highest Companion', () {
    final List<SeerahStationModel> stations = dataset.chronological;
    expect(stations.first.covenant, SeerahCovenant.preMission);
    expect(stations.first.timeLabel, 'عام الفيل');
    expect(stations.last.covenant, SeerahCovenant.medinan);
    expect(stations.map((SeerahStationModel s) => s.covenant).toSet(), SeerahCovenant.values.toSet());
    for (int i = 1; i < stations.length; i++) {
      expect(stations[i].order, greaterThan(stations[i - 1].order));
    }
  });

  group('the experience layer', () {
    test('every current station carries all three scenes, each backed by a verbatim, located quote', () {
      for (final SeerahStationModel station in dataset.stations) {
        expect(station.hasExperience, isTrue, reason: station.id);
        expect(station.hook, isNotNull, reason: station.id);
        expect(station.shuraQuestion, isNotNull, reason: station.id);
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
      final SeerahDataset tampered = editStation(first.id, (JsonMap json) {
        json['evidence'] = <dynamic>[
          for (final SeerahEvidence item in first.evidence)
            if (item.scene != SeerahScene.decision) item.toJson(),
        ];
      });
      expect(issuesOf(tampered), contains(contains('No evidence for scene "decision"')));
    });

    test('a half-written layer is rejected, and a hook needs the layer', () {
      final String id = dataset.chronological.first.id;
      expect(
        issuesOf(editStation(id, (JsonMap json) => json.remove('challenge'))),
        contains(contains('experience layer is incomplete')),
      );
      expect(
        issuesOf(editStation(id, (JsonMap json) {
          json
            ..remove('sceneDescription')
            ..remove('challenge')
            ..remove('propheticDecision')
            ..['evidence'] = <dynamic>[];
        })),
        contains(contains('hook and shura_question need the experience layer')),
      );
    });

    test('a station generated from the book, with chapters only, is valid', () {
      final SeerahDataset bare = editStation('badr_hubab_counsel', (JsonMap json) {
        json
          ..remove('sceneDescription')
          ..remove('challenge')
          ..remove('propheticDecision')
          ..remove('hook')
          ..remove('shura_question')
          ..remove('dilemma_options')
          ..['evidence'] = <dynamic>[];
      });
      expect(issuesOf(bare), isEmpty);
      final SeerahStationModel station = bare.stationById('badr_hubab_counsel')!;
      expect(station.hasExperience, isFalse);
      expect(station.chapters, isNotEmpty);
      expect(SeerahDataset.fromJson(bare.toJson()), bare);
    });

    test('scene evidence without the layer is rejected', () {
      final SeerahDataset stray = editStation('badr_hubab_counsel', (JsonMap json) {
        json
          ..remove('sceneDescription')
          ..remove('challenge')
          ..remove('propheticDecision')
          ..remove('hook')
          ..remove('shura_question')
          ..remove('dilemma_options');
      });
      expect(issuesOf(stray), contains(contains('Scene evidence without an experience layer')));
    });
  });

  group('the compass bar', () {
    test('every station states its time or its age with the quotes that say so', () {
      for (final SeerahStationModel station in dataset.stations) {
        expect(station.hasCompassFacts, isTrue, reason: station.id);
        expect(station.compassBasis, isNotEmpty, reason: station.id);
        for (final SourceRef basis in station.compassBasis!) {
          expect(basis.quote?.trim(), isNotEmpty, reason: station.id);
          expect(basis.locator?.trim(), isNotEmpty, reason: station.id);
        }
      }
      expect(dataset.stationById('hira_first_revelation')!.ageLabel, 'أربعون سنة');
      expect(dataset.stationById('prophet_death')!.yearLabel, isNull);
    });

    test('a year or age without a basis, or a basis without a year or age, is rejected', () {
      expect(
        issuesOf(editStation('hira_first_revelation', (JsonMap json) => json.remove('compass_basis'))),
        contains(contains('without compass_basis')),
      );
      expect(
        issuesOf(editStation('hira_first_revelation', (JsonMap json) {
          json
            ..remove('year_label')
            ..remove('age_label');
        })),
        contains(contains('compass_basis without year_label or age_label')),
      );
    });
  });

  group('the bridge between stations', () {
    test('every station links back and teases forward except at the two ends', () {
      final List<SeerahStationModel> stations = dataset.chronological;
      expect(stations.first.previousLink, isNull);
      expect(stations.last.nextHook, isNull);
      for (int i = 1; i < stations.length; i++) {
        expect(stations[i].previousLink, isNotEmpty, reason: stations[i].id);
      }
      for (int i = 0; i < stations.length - 1; i++) {
        expect(stations[i].nextHook, isNotEmpty, reason: stations[i].id);
      }
    });

    test('a link before the first station or a hook after the last is rejected', () {
      expect(
        issuesOf(editStation(dataset.chronological.first.id, (JsonMap json) => json['previous_link'] = 'ما قبل')),
        contains(contains('previous_link: The first station')),
      );
      expect(
        issuesOf(editStation(dataset.chronological.last.id, (JsonMap json) => json['next_hook'] = 'ما بعد')),
        contains(contains('next_hook: The last station')),
      );
      expect(
        issuesOf(editStation('badr_hubab_counsel', (JsonMap json) => json['previous_link'] = '   ')),
        contains(contains('previous_link: must not be blank')),
      );
    });
  });

  group('the chapters', () {
    test('every station reads in chapters of verbatim, located passages from known sources', () {
      for (final SeerahStationModel station in dataset.stations) {
        expect(station.chapters, isNotEmpty, reason: station.id);
        expect(station.passageCount, greaterThanOrEqualTo(station.chapters.length), reason: station.id);
        for (final SeerahChapter chapter in station.chapters) {
          expect(chapter.title.trim(), isNotEmpty);
          expect(chapter.passages, isNotEmpty, reason: '${station.id} ${chapter.id}');
          for (final SourceRef passage in chapter.passages) {
            expect(passage.quote?.trim(), isNotEmpty);
            expect(passage.locator?.trim(), isNotEmpty);
            expect(sources.byId(passage.sourceId), isNotNull, reason: passage.sourceId);
          }
        }
      }
    });

    test('no passage carries a trace of the digital edition markup', () {
      final RegExp residue = RegExp(r'</?span|PageV\d|###|~~|\bms\d{3}\b|\[\d+\]');
      for (final SeerahStationModel station in dataset.stations) {
        for (final SeerahChapter chapter in station.chapters) {
          for (final SourceRef passage in chapter.passages) {
            expect(residue.hasMatch(passage.quote!), isFalse, reason: '${station.id} ${chapter.id}');
          }
        }
      }
    });

    test('a station without chapters, a chapter without passages, or a passage without locator is rejected', () {
      expect(
        issuesOf(editStation('badr_hubab_counsel', (JsonMap json) => json['chapters'] = <dynamic>[])),
        contains(contains('needs at least one chapter')),
      );
      final SeerahStationModel badr = dataset.stationById('badr_hubab_counsel')!;
      expect(
        issuesOf(editStation('badr_hubab_counsel', (JsonMap json) {
          json['chapters'] = <dynamic>[
            <String, dynamic>{'id': 'c1', 'title': 'فصل', 'passages': <dynamic>[]},
          ];
        })),
        contains(contains('needs at least one passage')),
      );
      final JsonMap chapter = badr.chapters.first.toJson();
      final JsonMap passage = Map<String, dynamic>.of((chapter['passages'] as List<dynamic>).first as JsonMap)
        ..remove('locator');
      expect(
        issuesOf(editStation('badr_hubab_counsel', (JsonMap json) {
          json['chapters'] = <dynamic>[
            <String, dynamic>{...chapter, 'passages': <dynamic>[passage]},
          ];
        })),
        contains(contains('must carry its locator')),
      );
      passage
        ..['locator'] = 'ج1 ص1'
        ..['sourceId'] = 'no_such_source';
      expect(
        issuesOf(editStation('badr_hubab_counsel', (JsonMap json) {
          json['chapters'] = <dynamic>[
            <String, dynamic>{...chapter, 'passages': <dynamic>[passage]},
          ];
        })),
        contains(contains('Unknown sourceId "no_such_source"')),
      );
    });

    test('a repeated chapter id or a blank chapter title is rejected', () {
      final SeerahStationModel badr = dataset.stationById('badr_hubab_counsel')!;
      final List<dynamic> chapters = badr.chapters.map((SeerahChapter c) => c.toJson()).toList();
      expect(
        issuesOf(editStation('badr_hubab_counsel', (JsonMap json) {
          json['chapters'] = <dynamic>[chapters.first, chapters.first];
        })),
        contains(contains('Duplicate chapter id')),
      );
      expect(
        issuesOf(editStation('badr_hubab_counsel', (JsonMap json) {
          json['chapters'] = <dynamic>[
            <String, dynamic>{...(chapters.first as JsonMap), 'title': '  '},
          ];
        })),
        contains(contains('title: must not be blank')),
      );
    });
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
      return editStation('badr_hubab_counsel', (JsonMap json) => json['dilemma_options'] = options);
    }

    test('an option that is not in the challenge quotes is rejected', () {
      final List<String> issues = issuesOf(
        withOptions(<String>['الرأي والحرب والمكيدة', 'خيار لا أصل له في الشاهد']),
      );
      expect(issues, contains(contains('dilemma_options[1]')));
    });

    test('fewer than two options, or a repeated one, is rejected', () {
      expect(issuesOf(withOptions(<String>['الرأي والحرب والمكيدة'])), contains(contains('two distinct')));
      expect(
        issuesOf(withOptions(<String>['الرأي والحرب والمكيدة', 'الرأي والحرب والمكيدة'])),
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

  test('the schema requires chapters and the epoch, and never the optional layers', () {
    final JsonMap schema = _load('assets/data/schema/hadith_platform.schema.json');
    final JsonMap station = asJsonMap(asJsonMap(schema['\$defs'], 'defs')['SeerahStationModel'], 'station');
    final List<dynamic> required = station['required'] as List<dynamic>;
    expect(required, containsAll(<String>['chapters', 'epoch_id', 'covenant', 'evidence']));
    for (final String optional in <String>[
      'sceneDescription',
      'challenge',
      'propheticDecision',
      'hook',
      'shura_question',
      'previous_link',
      'next_hook',
      'year_label',
      'age_label',
      'compass_basis',
    ]) {
      expect(required, isNot(contains(optional)), reason: optional);
    }
    expect(station['additionalProperties'], isFalse);
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
