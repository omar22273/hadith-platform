// فحص بيانات المحتوى المحقون: الأحاديث 1–42 من الأربعين النووية.
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
  11: 'دع ما يريبك',
  12: 'من حسن إسلام المرء',
  13: 'أن تحب لأخيك ما تحب لنفسك',
  14: 'عصمة دم المسلم',
  15: 'قل خيراً أو اصمت',
  16: 'لا تغضب',
  17: 'الإحسان على كل شيء',
  18: 'اتق الله حيثما كنت',
  19: 'احفظ الله يحفظك',
  20: 'الحياء وكلام النبوة الأولى',
  21: 'قل آمنت بالله ثم استقم',
  22: 'أأدخل الجنة؟',
  23: 'الطهور شطر الإيمان',
  24: 'يا عبادي إني حرمت الظلم على نفسي',
  25: 'ذهب أهل الدثور بالأجور',
  26: 'كل سلامى عليه صدقة',
  27: 'البر حسن الخلق',
  28: 'عليكم بسنتي وسنة الخلفاء الراشدين',
  29: 'ملاك ذلك كله',
  30: 'فرض فرائض فلا تضيعوها',
  31: 'ازهد في الدنيا يحبك الله',
  32: 'لا ضرر ولا ضرار',
  33: 'البينة على المدعي',
  34: 'من رأى منكم منكراً',
  35: 'المسلم أخو المسلم',
  36: 'من نفّس عن مؤمن كربة',
  37: 'كتب الله الحسنات والسيئات',
  38: 'من عادى لي وليّاً',
  39: 'تجاوز الله عن الخطأ والنسيان',
  40: 'كن في الدنيا كأنك غريب',
  41: 'هواه تبعاً لما جئت به',
  42: 'يا ابن آدم إنك ما دعوتني',
};

/// آخر حديث في الأربعين النووية كما رتبها المصنف في هذا المسار.
const int _lastHadith = 42;

/// الحديثان اللذان لا نظير لهما في النسخ المثبتة من الكتب الستة؛ تخريجهما إلى نص الأربعين نفسه.
const Set<int> _arbaunOnlyTakhrij = <int>{30, 41};

const String _tuhfaSourceId = 'tuhfa_rabbaniyya';
const List<String> _pinnedCollections = <String>[
  'sahih_bukhari',
  'sahih_muslim',
  'sunan_tirmidhi',
  'sunan_ibn_majah',
  'sunan_nasai',
];

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
    test('hadiths 1 to 42 are registered in order and fill the planned path', () {
      expect(curriculum.plannedCount, _lastHadith);
      expect(curriculum.items.length, _lastHadith);
      for (int number = 1; number <= _lastHadith; number++) {
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

    test('the next-station teaser chain runs through all forty-two', () {
      for (int number = 1; number < _lastHadith; number++) {
        expect(curriculum.itemAfter(_idFor(number))?.hadithId, _idFor(number + 1));
      }
      expect(curriculum.itemAfter(_idFor(_lastHadith)), isNull);
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

  for (int number = 3; number <= _lastHadith; number++) {
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

      test('takhrij cites a pinned hadith collection with a number', () {
        final List<TakhrijReference> references = model.matn.takhrij.references;
        expect(references, isNotEmpty);
        for (final TakhrijReference reference in references) {
          expect(sources.byId(reference.sourceId), isNotNull, reason: reference.sourceId);
          expect(reference.hadithNumber.trim(), isNotEmpty);
        }
        expect(model.matn.takhrij.displayLabel.trim(), isNotEmpty);
        if (_arbaunOnlyTakhrij.contains(number)) {
          // لا نظير في النسخ المثبتة: التخريج إلى نص الأربعين نفسه، ولا يُختلق رقم في كتاب لم يُتحقق منه.
          expect(
            references.every((TakhrijReference r) => r.sourceId == 'arbaun_nawawiyya'),
            isTrue,
          );
        } else {
          expect(
            references.any((TakhrijReference r) => _pinnedCollections.contains(r.sourceId)),
            isTrue,
          );
        }
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

      test('three to sixteen ordered whole-phrase chunks with short labels', () {
        final List<PracticeChunk> chunks = model.practice.chunks;
        expect(chunks.length, inInclusiveRange(3, 16));
        expect(model.practice.reconstruction.chunkIds, chunks.map((PracticeChunk c) => c.id).toList());
        for (final PracticeChunk chunk in chunks) {
          expect(chunk.label.trim(), isNotEmpty);
          expect(chunk.label.length, lessThanOrEqualTo(40), reason: chunk.id);
          final MatnSegment segment = model.matn.segments.firstWhere((MatnSegment s) => s.id == chunk.segmentId);
          final List<MatnToken> tokens = MatnTokenizer.tokenize(segment.text);
          expect(chunk.startToken, greaterThanOrEqualTo(0));
          expect(chunk.endToken, lessThan(tokens.length));
          expect(chunk.startToken, lessThanOrEqualTo(chunk.endToken));
          if (tokens.length > 1) {
            expect(chunk.endToken - chunk.startToken + 1, greaterThanOrEqualTo(2), reason: '${chunk.id} is a phrase, not a word');
          }
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

  group('concise sharh from the pinned book', () {
    final RegExp noise = RegExp('[A-Za-z0-9<>{}\\[\\]*|~]');
    for (int number = 1; number <= _lastHadith; number++) {
      final String id = _idFor(number);
      test('$id carries the book sharh and anchors its gharib to it', () {
        final HadithDailyModel model = HadithDailyModel.fromJson(_load('$_hadithDir/$id.json'));
        final ConciseExplanation? explanation = model.conciseExplanation;
        expect(explanation, isNotNull, reason: 'missing concise_explanation');
        expect(explanation!.source.sourceId, _tuhfaSourceId);
        expect(sources.byId(_tuhfaSourceId), isNotNull);
        expect(explanation.source.locator, 'الحديث $number');
        expect(explanation.vocabulary, isNotEmpty);
        expect(explanation.benefits, isNotEmpty);
        for (final ExplanationTerm term in explanation.vocabulary) {
          expect(term.term.trim(), isNotEmpty);
          expect(term.explanation.trim(), isNotEmpty, reason: term.term);
          expect(noise.hasMatch(term.term + term.explanation), isFalse, reason: '${term.term} => ${term.explanation}');
        }
        for (final String benefit in explanation.benefits) {
          expect(benefit.trim(), isNotEmpty);
          expect(noise.hasMatch(benefit), isFalse, reason: benefit);
        }
        // الغريب كله من مفردات الكتاب نفسه نصاً.
        final Set<String> meanings = <String>{
          for (final ExplanationTerm term in explanation.vocabulary) term.explanation,
        };
        for (final GharibEntry entry in model.matn.gharib) {
          expect(entry.sources.first.sourceId, _tuhfaSourceId, reason: entry.id);
          expect(entry.sources.first.quote, entry.meaning, reason: entry.id);
          expect(meanings.contains(entry.meaning), isTrue, reason: '${entry.id}: ${entry.meaning}');
        }
      });
    }
  });
}
