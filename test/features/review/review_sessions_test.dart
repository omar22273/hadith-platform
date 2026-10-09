// اختبارات ميدان المراجعة: بناء المادة من الأوراد المكتملة، وطابور البطاقات،
// ولوحة الترتيب بالسحب والإفلات، وجلسة المواقف.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/hadith/domain/hadith_bundle.dart';
import 'package:hadith_platform/features/hadith/domain/practice_engine.dart';
import 'package:hadith_platform/features/review/domain/review_deck.dart';
import 'package:hadith_platform/features/review/domain/review_sessions.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

void main() {
  final NarratorCatalog narrators = NarratorCatalog.fromJson(_load('assets/data/catalogs/narrators.json'));
  final SourceCatalog sources = SourceCatalog.fromJson(_load('assets/data/catalogs/sources.json'));
  HadithBundle bundle(String id) {
    return HadithBundle(
      hadith: HadithDailyModel.fromJson(_load('assets/data/hadith/nawawi40/$id.json')),
      narrators: narrators,
      sources: sources,
    );
  }

  final List<HadithBundle> bundles = <HadithBundle>[bundle('nawawi40_001'), bundle('nawawi40_002')];
  final ReviewDeck deck = buildReviewDeck(bundles, seed: 42);

  group('deck', () {
    test('collects gharib, memorization chunks and scenarios from the files as they are', () {
      final int gharib = bundles.fold<int>(0, (int sum, HadithBundle b) => sum + b.hadith.matn.gharib.length);
      expect(deck.hadithCount, 2);
      expect(deck.flashcards.length, gharib);
      expect(deck.scenarios.length, 2);
      expect(deck.orderChallenges, isNotEmpty);
      final GharibEntry firstEntry = bundles.first.hadith.matn.gharib.first;
      expect(deck.flashcards.first.headword, firstEntry.headword);
      expect(deck.flashcards.first.meaning, firstEntry.meaning);
      expect(deck.flashcards.first.citation, isNotEmpty);
    });

    test('an empty list of completed hadiths gives an empty deck', () {
      expect(buildReviewDeck(const <HadithBundle>[], seed: 1).isEmpty, isTrue);
    });
  });

  group('flashcards', () {
    test('known cards leave the queue and repeated cards go to its end', () {
      FlashcardSession session = FlashcardSession.start(3);
      expect(session.current, 0);
      session = session.flip();
      expect(session.flipped, isTrue);
      session = session.repeatLater();
      expect(session.queue, <int>[1, 2, 0]);
      expect(session.flipped, isFalse);
      session = session.markKnown().markKnown().markKnown();
      expect(session.done, isTrue);
      expect(session.known, 3);
      expect(session.repeats, 1);
    });
  });

  group('word order', () {
    test('the right word is placed, a wrong one shakes back, and the chunk completes', () {
      final OrderChallenge challenge = deck.orderChallenges.first;
      OrderBoard board = OrderBoard.start(challenge.drill);
      final int length = challenge.drill.tokens.length;
      int wrongTile = -1;
      for (int id = 0; id < challenge.drill.tiles.length; id++) {
        if (!challenge.drill.fits(id, 0)) {
          wrongTile = id;
          break;
        }
      }
      if (wrongTile >= 0) {
        final (OrderBoard afterWrong, PlacementOutcome wrong) = board.place(wrongTile);
        expect(wrong, PlacementOutcome.mismatch);
        expect(afterWrong.placedTiles, isEmpty);
        expect(afterWrong.lastMismatchTile, wrongTile);
        board = afterWrong;
      }
      PlacementOutcome last = PlacementOutcome.ignored;
      for (int position = 0; position < length; position++) {
        final int tile = List<int>.generate(challenge.drill.tiles.length, (int i) => i)
            .firstWhere((int id) => !board.isUsed(id) && challenge.drill.fits(id, position));
        final (OrderBoard next, PlacementOutcome outcome) = board.place(tile);
        board = next;
        last = outcome;
      }
      expect(last, PlacementOutcome.completed);
      expect(board.completed, isTrue);
      final (OrderBoard same, PlacementOutcome ignored) = board.place(board.placedTiles.first);
      expect(ignored, PlacementOutcome.ignored);
      expect(same.placedTiles.length, length);
      expect(board.undo().placedTiles.length, length - 1);
    });

    test('tiles show the vocalized words of the matn exactly', () {
      final OrderChallenge challenge = deck.orderChallenges.first;
      final Set<String> tokens = challenge.drill.tokens.map((MatnToken t) => t.core).toSet();
      for (final PracticeTile tile in challenge.drill.tiles) {
        expect(tokens, contains(tile.token.core));
      }
    });
  });

  group('scenarios', () {
    test('a choice can be changed and each scenario keeps its own choice', () {
      ScenarioQuizSession session = ScenarioQuizSession.initial;
      final String first = deck.scenarios.first.scenario.options.first.id;
      final String second = deck.scenarios.first.scenario.options.last.id;
      session = session.choose(first).choose(second);
      expect(session.currentChoice, second);
      session = session.goTo(1);
      expect(session.currentChoice, isNull);
      expect(session.goTo(0).currentChoice, second);
    });
  });

  group('sequential order challenges', () {
    test('only the first unfinished challenge is open', () {
      expect(openChallengeLimit(<int>{}, 4), 0);
      expect(openChallengeLimit(<int>{0}, 4), 1);
      expect(openChallengeLimit(<int>{0, 1}, 4), 2);
      expect(openChallengeLimit(<int>{1}, 4), 0, reason: 'completing a later one does not unlock past a gap');
    });

    test('when all are completed the last stays open, and an empty deck is safe', () {
      expect(openChallengeLimit(<int>{0, 1, 2}, 3), 2);
      expect(openChallengeLimit(<int>{}, 0), 0);
    });
  });
}
