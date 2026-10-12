// اختبارات محرك التثبيت، ومقارنة الروايات، وشجرة الإسناد على بيانات الحديث الأول.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/daily_session/domain/sanad_tree.dart';
import 'package:hadith_platform/features/daily_session/domain/variant_diff.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/hadith/domain/practice_engine.dart';

HadithDailyModel _hadith(String id) {
  final String path = 'assets/data/hadith/nawawi40/$id.json';
  return HadithDailyModel.fromJson(asJsonMap(jsonDecode(File(path).readAsStringSync()), path));
}

void main() {
  final HadithDailyModel first = _hadith('nawawi40_001');

  group('practice engine', () {
    final PracticeEngine engine = PracticeEngine.fromHadith(first, seed: 20261009);

    test('groups the reconstruction phrases into drills of at most four', () {
      final int phrases = first.practice.reconstruction.chunkIds.length;
      expect(engine.drills.fold<int>(0, (int sum, ChunkDrill d) => sum + d.tokens.length), phrases);
      expect(engine.drills.every((ChunkDrill d) => d.tokens.length >= 2 && d.tokens.length <= maxPhrasesPerDrill), isTrue);
      expect(engine.drills.map((ChunkDrill d) => d.chunks.length).toList(), phraseGroupSizes(phrases));
    });

    test('tiles are a shuffled permutation of the drill phrases', () {
      for (final ChunkDrill drill in engine.drills) {
        final List<int> order = drill.tiles.map((PracticeTile t) => t.tokenIndex).toList();
        expect((List<int>.of(order)..sort()), List<int>.generate(drill.tokens.length, (int i) => i));
        if (drill.tokens.length > 1) {
          expect(order, isNot(List<int>.generate(drill.tokens.length, (int i) => i)));
        }
        final PracticeTile firstPhrase = drill.tiles.firstWhere((PracticeTile t) => t.tokenIndex == 0);
        expect(drill.fits(firstPhrase.id, 0), isTrue);
      }
    });

    test('the hint is the next correct phrase, and only after three consecutive mistakes', () {
      for (final ChunkDrill drill in engine.drills) {
        final List<int> placed = <int>[];
        for (int position = 0; position < drill.tokens.length; position++) {
          expect(drill.hintTile(placed, 0), isNull);
          expect(drill.hintTile(placed, hintAfterMistakes - 1), isNull, reason: 'two mistakes are not enough');
          final int? hint = drill.hintTile(placed, hintAfterMistakes);
          expect(hint, isNotNull);
          expect(placed, isNot(contains(hint)));
          expect(drill.fits(hint!, position), isTrue, reason: 'it is a phrase that belongs at ${position + 1}');
          expect(drill.hintTile(placed, hintAfterMistakes + 4), hint, reason: 'it stays on the same phrase');
          placed.add(hint);
        }
        expect(drill.hintTile(placed, hintAfterMistakes), isNull, reason: 'nothing to hint once complete');
        expect(drill.nextTileAfter(placed), isNull);
      }
    });

    test('the same seed gives the same shuffle', () {
      final PracticeEngine again = PracticeEngine.fromHadith(first, seed: 20261009);
      for (int d = 0; d < engine.drills.length; d++) {
        expect(
          again.drills[d].tiles.map((PracticeTile t) => t.tokenIndex).toList(),
          engine.drills[d].tiles.map((PracticeTile t) => t.tokenIndex).toList(),
        );
      }
    });

    test('vanishing grows monotonically and starts with the priority anchors', () {
      final Set<int> low = engine.hiddenAt(0);
      final Set<int> mid = engine.hiddenAt(1);
      final Set<int> high = engine.hiddenAt(2);
      expect(mid.containsAll(low), isTrue);
      expect(high.containsAll(mid), isTrue);
      for (final TokenAnchor anchor in first.practice.vanishing.priorityAnchors) {
        final int index = engine.words.indexWhere(
          (VanishWord w) => w.segmentId == anchor.segmentId && w.tokenIndex == anchor.tokenIndex,
        );
        expect(low.contains(index), isTrue, reason: anchor.surface);
      }
      expect(low.length, (engine.hideOrder.length * engine.levels.first / 100).round());
    });

    test('the honorific is never hidden', () {
      final HadithDailyModel second = _hadith('nawawi40_002');
      final PracticeEngine other = PracticeEngine.fromHadith(second, seed: 7);
      for (final int index in other.hiddenAt(other.levels.length - 1)) {
        expect(other.words[index].token.isHonorific, isFalse);
      }
    });
  });

  group('variant diff', () {
    test('compares on the consonantal skeleton', () {
      expect(rasm('بِالنِّيَّاتِ'), 'بالنيات');
      expect(rasm('أَعْمَالُ'), 'اعمال');
    });

    test('marks words that have no counterpart in the base text', () {
      final List<DiffWord> words = diffVariant(
        variantText: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّةِ',
        baseText: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
      );
      expect(words.map((DiffWord w) => w.shared).toList(), <bool>[true, true, false]);
    });
  });

  group('sanad tree', () {
    final SanadTree tree = SanadTree.build(first.scholar.chains);

    test('starts with the Prophet and carries every chain', () {
      expect(tree.roots.length, 1);
      expect(tree.roots.single.narratorId, 'prophet');
      for (final SanadChain chain in first.scholar.chains) {
        expect(tree.roots.single.chainIds, contains(chain.id));
      }
    });

    test('merges shared links and lays out one column per distinct path', () {
      expect(tree.depth, 8);
      expect(tree.columns, 3);
      expect(tree.nodes.length, 12);
      expect(tree.edges.length, tree.nodes.length - tree.roots.length);
    });
  });
}
