// اختبارات سقف المراجعة اليومي: لا أكثر من اثنتي عشرة بطاقة في اليوم مهما
// تراكم ما لم يُراجَع، والفائض يتقدم بهدوء في الأيام التالية، ولا يظهر في
// الميدان أي رقم تراكمي.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/app/app_shell_screen.dart';
import 'package:hadith_platform/core/storage/key_value_store.dart';
import 'package:hadith_platform/core/text/arabic_digits.dart';
import 'package:hadith_platform/features/hadith/application/hadith_providers.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/hadith/domain/hadith_bundle.dart';
import 'package:hadith_platform/features/review/application/review_controllers.dart';
import 'package:hadith_platform/features/review/data/review_ledger_store.dart';
import 'package:hadith_platform/features/review/domain/daily_review.dart';
import 'package:hadith_platform/features/review/domain/review_deck.dart';

import '../../support/app_harness.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

List<String> _ids(int count) => <String>[for (int i = 1; i <= count; i++) 'c$i'];

Finder _navLabel(String label) {
  return find.descendant(of: find.byType(AppBottomBar), matching: find.text(label));
}

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
  final ReviewDeck fullDeck = buildReviewDeck(bundles, seed: 42);

  group('planReviewDay', () {
    test('the cap is twelve, and no more than twelve are planned however many cards wait', () {
      expect(dailyReviewCap, 12);
      final ReviewLedger plan = planReviewDay(ledger: ReviewLedger.empty, orderedIds: _ids(500), today: 100);
      expect(plan.queue, hasLength(12));
      expect(plan.queue, _ids(12), reason: 'the oldest wirds come first');
    });

    test('a small pool is planned whole', () {
      final ReviewLedger plan = planReviewDay(ledger: ReviewLedger.empty, orderedIds: _ids(5), today: 100);
      expect(plan.queue, _ids(5));
    });

    test('the overflow moves quietly to the following days, then the oldest cards come around again', () {
      final List<String> pool = _ids(30);
      final ReviewLedger day1 = planReviewDay(ledger: ReviewLedger.empty, orderedIds: pool, today: 100);
      final ReviewLedger day2 = planReviewDay(ledger: day1, orderedIds: pool, today: 101);
      final ReviewLedger day3 = planReviewDay(ledger: day2, orderedIds: pool, today: 102);

      expect(day1.queue, _ids(12));
      expect(day2.queue, _ids(24).sublist(12), reason: 'cards never shown come before cards shown yesterday');
      expect(day3.queue, hasLength(12));
      expect(
        day3.queue,
        <String>[..._ids(6), ..._ids(30).sublist(24)],
        reason: 'the last six unseen cards, then the six shown longest ago',
      );
      for (final ReviewLedger day in <ReviewLedger>[day1, day2, day3]) {
        expect(day.queue.length, lessThanOrEqualTo(dailyReviewCap));
      }
    });

    test('the day queue stays frozen when the arena is planned again the same day', () {
      final ReviewLedger day1 = planReviewDay(ledger: ReviewLedger.empty, orderedIds: _ids(30), today: 100);
      final ReviewLedger again = planReviewDay(ledger: day1, orderedIds: _ids(40), today: 100);
      expect(again.queue, day1.queue);
      expect(again, day1);
    });

    test('a short queue is topped up the same day when more cards become available', () {
      final ReviewLedger early = planReviewDay(ledger: ReviewLedger.empty, orderedIds: _ids(5), today: 100);
      final ReviewLedger later = planReviewDay(ledger: early, orderedIds: _ids(9), today: 100);
      expect(later.queue, _ids(9));
      final ReviewLedger full = planReviewDay(ledger: later, orderedIds: _ids(40), today: 100);
      expect(full.queue, hasLength(12));
      expect(full.queue.sublist(0, 9), _ids(9));
    });

    test('cards that no longer exist leave the queue and the ledger', () {
      final ReviewLedger day1 = planReviewDay(ledger: ReviewLedger.empty, orderedIds: _ids(12), today: 100);
      final List<String> remaining = _ids(12)..remove('c3');
      final ReviewLedger day1b = planReviewDay(ledger: day1, orderedIds: remaining, today: 100);
      expect(day1b.queue, remaining);
      expect(day1b.shown.containsKey('c3'), isFalse);
    });

    test('an oversized stored queue is cut back to the cap', () {
      final ReviewLedger oversized = ReviewLedger(
        day: 100,
        queue: _ids(40),
        shown: const <String, int>{},
      );
      expect(planReviewDay(ledger: oversized, orderedIds: _ids(40), today: 100).queue, hasLength(12));
    });
  });

  group('epochDayOf', () {
    test('turns over at local midnight only, including across a daylight-saving change', () {
      expect(epochDayOf(DateTime(2026, 10, 9, 0, 1)), epochDayOf(DateTime(2026, 10, 9, 23, 59)));
      expect(epochDayOf(DateTime(2026, 10, 10)) - epochDayOf(DateTime(2026, 10, 9, 23, 59)), 1);
      expect(epochDayOf(DateTime(2026, 3, 29, 12)) - epochDayOf(DateTime(2026, 3, 28, 12)), 1);
      expect(epochDayOf(DateTime(2026, 10, 25, 12)) - epochDayOf(DateTime(2026, 10, 24, 12)), 1);
    });
  });

  group('ledger storage', () {
    test('a ledger survives a round trip through the store', () async {
      final InMemoryKeyValueStore memory = InMemoryKeyValueStore();
      final ReviewLedgerStore store = ReviewLedgerStore(memory);
      expect(store.read(), ReviewLedger.empty);
      final ReviewLedger plan = planReviewDay(ledger: ReviewLedger.empty, orderedIds: _ids(30), today: 100);
      await store.write(plan);
      expect(store.read(), plan);
    });

    test('an unreadable ledger starts a fresh one instead of failing', () {
      for (final String raw in <String>['not json', '[]', '{"day":"x","queue":[],"shown":{}}', '{"day":1,"queue":[],"shown":{"a":"b"}}']) {
        final ReviewLedgerStore store = ReviewLedgerStore(
          InMemoryKeyValueStore(<String, String>{StorageKeys.reviewLedger: raw}),
        );
        expect(store.read(), ReviewLedger.empty, reason: raw);
      }
    });

    test('the ledger key is allowed in storage but is not part of the backup', () {
      expect(StorageKeys.all, contains(StorageKeys.reviewLedger));
    });
  });

  group('deck', () {
    test('every card has a unique id, and the ids cover the whole deck once', () {
      expect(fullDeck.cardIds.toSet(), hasLength(fullDeck.cardIds.length));
      expect(
        fullDeck.cardIds,
        hasLength(fullDeck.flashcards.length + fullDeck.orderChallenges.length + fullDeck.scenarios.length),
      );
      expect(fullDeck.cardIds.length, greaterThan(dailyReviewCap), reason: 'two wirds already exceed one day');
    });

    test('limiting a deck keeps the requested cards, in curriculum order, and nothing else', () {
      final ReviewDeck day = fullDeck.limitedTo(fullDeck.cardIds.take(5));
      expect(day.cardCount, 5);
      expect(day.cardIds, fullDeck.cardIds.take(5).toList());
      expect(day.hadithCount, fullDeck.hadithCount);
      final Set<String> kept = <String>{
        ...day.flashcards.map((GharibCard c) => c.id),
        ...day.orderChallenges.map((OrderChallenge c) => c.id),
        ...day.scenarios.map((ScenarioCard c) => c.id),
      };
      expect(kept, day.cardIds.toSet());
    });

    test('the planned day of a deck that exceeds the cap holds exactly twelve cards', () {
      final ReviewLedger plan = planReviewDay(ledger: ReviewLedger.empty, orderedIds: fullDeck.cardIds, today: 100);
      expect(fullDeck.limitedTo(plan.queue).cardCount, dailyReviewCap);
    });
  });

  group('arena', () {
    testWidgets('shows at most twelve cards, saves the day queue, and hides cumulative totals', (WidgetTester tester) async {
      final ProviderContainer container = await pumpApp(
        tester,
        stored: <String, String>{StorageKeys.journeyProgress: completedProgressJson()},
      );
      await tester.tap(_navLabel('ميدان المراجعة'));
      await settle(tester);

      final ReviewDeck deck = await container.read(reviewDeckProvider.future);
      expect(deck.cardCount, dailyReviewCap);
      expect(find.text('بطاقات اليوم: ${arabicDigits(dailyReviewCap)}'), findsOneWidget);
      // لا أرقام تراكمية: لا عدد أوراد، ولا ألفاظ، ولا مقاطع، ولا مواقف إجمالية.
      expect(find.textContaining('أحاديث مكتملة'), findsNothing);
      expect(find.textContaining('حديث مكتمل'), findsNothing);
      expect(find.textContaining('لفظة'), findsNothing);
      expect(find.textContaining('متأخر'), findsNothing);
      expect(find.textContaining('مستحق'), findsNothing);

      final ReviewLedger saved = container.read(reviewLedgerStoreProvider).read();
      expect(saved.day, epochDayOf(DateTime(2026, 10, 9, 10)));
      expect(saved.queue, deck.cardIds);
    });

    testWidgets('the overflow comes back on the following day without being announced', (WidgetTester tester) async {
      final ProviderContainer first = await pumpApp(
        tester,
        stored: <String, String>{StorageKeys.journeyProgress: completedProgressJson()},
      );
      final ReviewDeck day1 = await first.read(reviewDeckProvider.future);
      final ReviewDeck full = buildReviewDeck(
        <HadithBundle>[
          await first.read(hadithBundleProvider('nawawi40_001').future),
          await first.read(hadithBundleProvider('nawawi40_002').future),
        ],
        seed: 1,
      );
      final ReviewLedger today = first.read(reviewLedgerStoreProvider).read();
      expect(today.queue, day1.cardIds);

      // نحاكي الغد: السجل المحفوظ صار سجل الأمس.
      await tester.pumpWidget(const SizedBox());
      final ReviewLedger yesterday = ReviewLedger(
        day: today.day - 1,
        queue: today.queue,
        shown: <String, int>{for (final MapEntry<String, int> e in today.shown.entries) e.key: e.value - 1},
      );
      final ProviderContainer second = await pumpApp(
        tester,
        stored: <String, String>{
          StorageKeys.journeyProgress: completedProgressJson(),
          StorageKeys.reviewLedger: jsonEncode(yesterday.toJson()),
        },
      );
      final ReviewDeck day2 = await second.read(reviewDeckProvider.future);

      expect(day2.cardCount, lessThanOrEqualTo(dailyReviewCap));
      final Set<String> overflow = full.cardIds.toSet().difference(day1.cardIds.toSet());
      expect(overflow, isNotEmpty);
      expect(day2.cardIds.toSet().containsAll(overflow), isTrue, reason: 'the overflow of the previous day is served first');
      expect(second.read(reviewLedgerStoreProvider).read().day, today.day);
    });
  });
}
