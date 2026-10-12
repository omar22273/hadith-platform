// فحص بيانات المحتوى المحقون: الأحاديث 1–10 من الأربعين النووية.
//
// يتحقق من وجود كل محطة في الفهرس، وقراءة ملفها، وتطابق هويتها وعنوانها،
// وسلامة المقاطع والغريب والتشكيل والمصادر، دون أي اعتماد على الشبكة.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';

const String _narratorsPath = 'assets/data/catalogs/narrators.json';
const String _sourcesPath = 'assets/data/catalogs/sources.json';
const String _curriculumPath = 'assets/data/curriculum/nawawi40_curriculum.json';
const String _hadithDir = 'assets/data/hadith/nawawi40';

const Map<int, String> _expectedTitles = <int, String>{
  3: 'أركان الإسلام الخمسة',
  4: 'مراحل خلق الإنسان والقدر',
  5: 'رد البدع والمحدثات',
  6: 'الحلال بيّن والحرام بيّن والشبهات',
  7: 'الدين النصيحة',
  8: 'حرمة دم المسلم وماله',
  9: 'اجتناب ما نهى عنه والأمر بالاستطاعة',
  10: 'أكل الحلال وأثر طيب المطعم في استجابة الدعاء',
};

final RegExp _harakat = RegExp('[ً-ْٰ]');
final RegExp _arabicLetter = RegExp('[ء-ي]');
final RegExp _hamzaBelowWithoutKasra = RegExp('إ(?![ً-ْ]*ِ)');

JsonMap _load(String path) {
  final Object? decoded = jsonDecode(File(path).readAsStringSync());
  return asJsonMap(decoded, path);
}

String _idFor(int number) => 'nawawi40_${number.toString().padLeft(3, '0')}';

void main() {
  final CurriculumManifest curriculum = CurriculumManifest.fromJson(_load(_curriculumPath));
  final NarratorCatalog narrators = NarratorCatalog.fromJson(_load(_narratorsPath));
  final SourceCatalog sources = SourceCatalog.fromJson(_load(_sourcesPath));
  final HadithIntegrityChecker checker = HadithIntegrityChecker(
    narrators: narrators,
    sources: sources,
  );

  CurriculumItem? itemFor(String hadithId) {
    for (final CurriculumItem item in curriculum.items) {
      if (item.hadithId == hadithId) {
        return item;
      }
    }
    return null;
  }

  group('curriculum index', () {
    test('hadiths 1 to 10 are registered in order', () {
      for (int number = 1; number <= 10; number++) {
        final CurriculumItem? item = itemFor(_idFor(number));
        expect(item, isNotNull, reason: 'missing station $number');
        expect(item!.number, number);
        expect(item.assetPath, '$_hadithDir/${_idFor(number)}.json');
      }
    });

    test('the requested titles match the index', () {
      _expectedTitles.forEach((int number, String title) {
        expect(itemFor(_idFor(number))?.title, title, reason: 'hadith $number');
      });
    });

    test('the next-station teaser chain runs through the first ten', () {
      for (int number = 1; number < 10; number++) {
        expect(curriculum.itemAfter(_idFor(number))?.hadithId, _idFor(number + 1));
      }
      expect(curriculum.itemAfter(_idFor(10)), isNull);
    });

    test('every asset lives in the registered folder', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/data/hadith/nawawi40/'));
      for (final CurriculumItem item in curriculum.items) {
        expect(item.assetPath.startsWith('$_hadithDir/'), isTrue, reason: item.hadithId);
        expect(File(item.assetPath).existsSync(), isTrue, reason: item.assetPath);
      }
    });
  });

  for (int number = 3; number <= 10; number++) {
    final String id = _idFor(number);
    group(id, () {
      late HadithDailyModel model;
      late JsonMap json;

      setUp(() {
        json = _load('$_hadithDir/$id.json');
        model = HadithDailyModel.fromJson(json);
      });

      test('identity and title', () {
        expect(model.id, id);
        expect(model.sequence, number);
        expect(model.collection.numberInCollection, number);
        expect(model.title, _expectedTitles[number]);
        expect(model.milestone.trim(), isNotEmpty);
        expect(model.teaser.text.trim(), isNotEmpty);
      });

      test('round trip is lossless and the integrity checker is silent', () {
        expect(model.toJson(), equals(json));
        final List<IntegrityIssue> issues = checker.check(model);
        expect(issues, isEmpty, reason: issues.map((IntegrityIssue i) => i.toString()).join('\n'));
      });

      test('takhrij cites Bukhari or Muslim with a number', () {
        final List<TakhrijReference> references = model.matn.takhrij.references;
        expect(references, isNotEmpty);
        for (final TakhrijReference reference in references) {
          expect(sources.byId(reference.sourceId), isNotNull, reason: reference.sourceId);
          expect(reference.hadithNumber.trim(), isNotEmpty);
        }
        expect(model.matn.takhrij.displayLabel.trim(), isNotEmpty);
        expect(
          model.matn.takhrij.references.any(
            (TakhrijReference r) => r.sourceId.contains('bukhari') || r.sourceId.contains('muslim'),
          ),
          isTrue,
        );
      });

      test('context is present and sourced', () {
        expect(model.context.narrative.trim(), isNotEmpty);
        expect(model.context.sources, isNotEmpty);
      });

      test('matn is fully vocalized', () {
        expect(model.matn.segments, isNotEmpty);
        for (final MatnSegment segment in model.matn.segments) {
          expect(_hamzaBelowWithoutKasra.hasMatch(segment.text), isFalse, reason: segment.id);
          for (final MatnToken token in MatnTokenizer.tokenize(segment.text)) {
            if (!_arabicLetter.hasMatch(token.core)) {
              continue;
            }
            expect(_harakat.hasMatch(token.core), isTrue, reason: '${segment.id}: ${token.core}');
          }
        }
      });

      test('three or four ordered chunks with short labels', () {
        final List<PracticeChunk> chunks = model.practice.chunks;
        expect(chunks.length, inInclusiveRange(3, 4));
        expect(model.practice.reconstruction.chunkIds, chunks.map((PracticeChunk c) => c.id).toList());
        for (final PracticeChunk chunk in chunks) {
          expect(chunk.label.trim(), isNotEmpty);
          expect(chunk.label.length, lessThanOrEqualTo(40), reason: chunk.id);
          final MatnSegment segment = model.matn.segments.firstWhere((MatnSegment s) => s.id == chunk.segmentId);
          final List<MatnToken> tokens = MatnTokenizer.tokenize(segment.text);
          expect(chunk.startToken, greaterThanOrEqualTo(0));
          expect(chunk.endToken, lessThan(tokens.length));
          expect(chunk.startToken, lessThanOrEqualTo(chunk.endToken));
        }
        for (int i = 1; i < chunks.length; i++) {
          final PracticeChunk previous = chunks[i - 1];
          final PracticeChunk current = chunks[i];
          final int previousIndex = model.matn.segments.indexWhere((MatnSegment s) => s.id == previous.segmentId);
          final int currentIndex = model.matn.segments.indexWhere((MatnSegment s) => s.id == current.segmentId);
          final bool ordered = currentIndex > previousIndex ||
              (currentIndex == previousIndex && current.startToken > previous.endToken);
          expect(ordered, isTrue, reason: '${previous.id} -> ${current.id}');
        }
      });

      test('two to four gharib terms anchored to the matn', () {
        final List<GharibEntry> gharib = model.matn.gharib;
        expect(gharib.length, inInclusiveRange(2, 4));
        for (final GharibEntry entry in gharib) {
          expect(entry.headword.trim(), isNotEmpty);
          expect(entry.meaning.trim(), isNotEmpty);
          expect(entry.sources, isNotEmpty, reason: entry.id);
          final MatnSegment segment = model.matn.segments.firstWhere((MatnSegment s) => s.id == entry.anchor.segmentId);
          final List<MatnToken> tokens = MatnTokenizer.tokenize(segment.text);
          expect(entry.anchor.tokenIndex + entry.anchor.length, lessThanOrEqualTo(tokens.length));
          final String joined = tokens
              .sublist(entry.anchor.tokenIndex, entry.anchor.tokenIndex + entry.anchor.length)
              .map((MatnToken t) => t.core)
              .join(' ');
          expect(entry.anchor.surface, joined, reason: entry.id);
        }
      });

      test('reflection has a scenario, a question and one aligned option', () {
        final Scenario scenario = model.reflection.scenario;
        expect(scenario.situation.trim(), isNotEmpty);
        expect(scenario.question.trim(), isNotEmpty);
        expect(scenario.options.length, greaterThanOrEqualTo(2));
        expect(
          scenario.options.where((ScenarioOption o) => o.alignment == OptionAlignment.aligned).length,
          1,
        );
        for (final ScenarioOption option in scenario.options) {
          expect(option.feedback.trim(), isNotEmpty);
        }
        expect(model.reflection.impacts, isNotEmpty);
      });

      test('every source id resolves and the hadith awaits scholarly review', () {
        expect(sources.byId(model.provenance.matnSource.sourceId), isNotNull);
        for (final VocalizationEdit edit in model.provenance.vocalizationEdits) {
          expect(edit.after.trim(), isNotEmpty);
        }
        expect(model.review.status.wire, 'pending_scholarly_review');
      });
    });
  }
}
