// اختبارات نماذج البيانات: التحويل ذهاباً وإياباً، وسلامة الأوراد، والتقسيم.
//
// إذا كان اسم الحزمة في pubspec.yaml غير hadith_platform فعدّل سطر الاستيراد.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';

const String _narratorsPath = 'assets/data/catalogs/narrators.json';
const String _sourcesPath = 'assets/data/catalogs/sources.json';
const String _curriculumPath =
    'assets/data/curriculum/nawawi40_curriculum.json';
const String _wisdomPath = 'assets/data/catalogs/wisdom_bank.json';

JsonMap _load(String path) {
  final Object? decoded = jsonDecode(File(path).readAsStringSync());
  return asJsonMap(decoded, path);
}

void main() {
  final CurriculumManifest curriculum =
      CurriculumManifest.fromJson(_load(_curriculumPath));
  final NarratorCatalog narrators =
      NarratorCatalog.fromJson(_load(_narratorsPath));
  final SourceCatalog sources = SourceCatalog.fromJson(_load(_sourcesPath));
  final HadithIntegrityChecker checker = HadithIntegrityChecker(
    narrators: narrators,
    sources: sources,
  );

  group('round trip', () {
    for (final CurriculumItem item in curriculum.items) {
      test('HadithDailyModel ${item.hadithId}', () {
        final JsonMap json = _load(item.assetPath);
        final HadithDailyModel model = HadithDailyModel.fromJson(json);
        expect(model.id, item.hadithId);
        expect(model.toJson(), equals(json));
        expect(HadithDailyModel.fromJson(model.toJson()), equals(model));
        expect(
          HadithDailyModel.fromJson(model.toJson()).hashCode,
          model.hashCode,
        );
      });
    }

    test('NarratorCatalog', () {
      final JsonMap json = _load(_narratorsPath);
      expect(NarratorCatalog.fromJson(json).toJson(), equals(json));
    });

    test('SourceCatalog', () {
      final JsonMap json = _load(_sourcesPath);
      expect(SourceCatalog.fromJson(json).toJson(), equals(json));
    });

    test('CurriculumManifest', () {
      final JsonMap json = _load(_curriculumPath);
      expect(CurriculumManifest.fromJson(json).toJson(), equals(json));
    });

    test('WisdomCatalog', () {
      final JsonMap json = _load(_wisdomPath);
      expect(WisdomCatalog.fromJson(json).toJson(), equals(json));
    });
  });

  group('integrity', () {
    for (final CurriculumItem item in curriculum.items) {
      test('${item.hadithId} has no integrity issues', () {
        final HadithDailyModel model =
            HadithDailyModel.fromJson(_load(item.assetPath));
        expect(checker.check(model), isEmpty);
      });
    }

    test('a broken anchor is reported', () {
      final HadithDailyModel model =
          HadithDailyModel.fromJson(_load(curriculum.items.first.assetPath));
      final GharibEntry entry = model.matn.gharib.first;
      final JsonMap json = model.toJson();
      final List<dynamic> gharib = json['matn']['gharib'] as List<dynamic>;
      final JsonMap brokenEntry = asJsonMap(gharib.first, 'gharib[0]');
      brokenEntry['anchor'] = <String, dynamic>{
        'segmentId': entry.anchor.segmentId,
        'tokenIndex': entry.anchor.tokenIndex + 1,
        'length': entry.anchor.length,
        'surface': entry.anchor.surface,
      };
      gharib[0] = brokenEntry;
      final HadithDailyModel broken = HadithDailyModel.fromJson(json);
      expect(checker.check(broken), isNotEmpty);
    });

    test('every curriculum asset exists', () {
      for (final CurriculumItem item in curriculum.items) {
        expect(File(item.assetPath).existsSync(), isTrue);
      }
    });

    test('curriculum indexes match the hadith files', () {
      for (final CurriculumItem item in curriculum.items) {
        final HadithDailyModel model =
            HadithDailyModel.fromJson(_load(item.assetPath));
        expect(model.title, item.title);
        expect(model.collection.numberInCollection, item.number);
        expect(model.milestone.trim(), isNotEmpty);
      }
    });

    test('hadith data carries no post-prophetic geographic stations', () {
      for (final CurriculumItem item in curriculum.items) {
        final JsonMap json = _load(item.assetPath);
        expect(json.containsKey('journey'), isFalse, reason: item.hadithId);
        final Object? place = (json['context'] as Map<String, dynamic>)['place'];
        if (place is Map<String, dynamic>) {
          expect(place.containsKey('stationId'), isFalse, reason: item.hadithId);
          expect(place['relation'], isNot('transmission_location'));
        }
      }
      expect(File('assets/data/catalogs/journey_stations.json').existsSync(), isFalse);
    });

    test('the planned path covers the whole collection', () {
      expect(curriculum.plannedCount, 42);
      final Set<int> numbers = <int>{for (final CurriculumItem item in curriculum.items) item.number};
      expect(numbers.length, curriculum.items.length);
      expect(numbers.every((int n) => n >= 1 && n <= curriculum.plannedCount), isTrue);
    });

    test('every wisdom entry is quoted verbatim with its speaker', () {
      final WisdomCatalog wisdom = WisdomCatalog.fromJson(_load(_wisdomPath));
      for (final WisdomEntry entry in wisdom.entries) {
        final String quote = entry.source.quote ?? '';
        expect(quote, contains(entry.text), reason: entry.id);
        expect(quote, contains(entry.speaker), reason: entry.id);
        expect(sources.byId(entry.source.sourceId), isNotNull);
      }
    });
  });

  group('curriculum', () {
    test('tomorrow teaser comes from the next item', () {
      final CurriculumItem? next = curriculum.itemAfter('nawawi40_001');
      expect(next?.hadithId, 'nawawi40_002');
      expect(curriculum.itemAfter('nawawi40_002'), isNull);
    });

    test('daily cap message is the blueprint wording', () {
      expect(
        curriculum.dailyCap.completionMessage,
        'أتممت وِردك اليومي.. العلم يُنال باللبنة فوق اللبنة',
      );
      expect(curriculum.dailyCap.unlockAt, UnlockAnchor.fajr);
    });
  });

  group('tokenizer', () {
    test('peels punctuation off both ends', () {
      final List<MatnToken> tokens =
          MatnTokenizer.tokenize('قَالَ: «نَعَمْ».');
      expect(tokens.length, 2);
      expect(tokens[0].core, 'قَالَ');
      expect(tokens[0].trailing, ':');
      expect(tokens[1].leading, '«');
      expect(tokens[1].core, 'نَعَمْ');
      expect(tokens[1].trailing, '».');
    });

    test('recognizes the honorific', () {
      final List<MatnToken> tokens =
          MatnTokenizer.tokenize('رَسُولَ اللَّهِ ﷺ يَقُولُ');
      expect(tokens[2].isHonorific, isTrue);
    });

    test('returns an empty list for blank text', () {
      expect(MatnTokenizer.tokenize('   '), isEmpty);
    });
  });

  group('parsing errors', () {
    test('a missing key throws JsonParseException', () {
      expect(
        () => SourceRef.fromJson(const <String, dynamic>{'locator': null}),
        throwsA(isA<JsonParseException>()),
      );
    });

    test('an unknown enum value throws JsonParseException', () {
      expect(
        () => SegmentVoice.fromWire('narrator'),
        throwsA(isA<JsonParseException>()),
      );
    });
  });
}
