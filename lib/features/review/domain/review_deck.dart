// مادة ميدان المراجعة: تُبنى من الأوراد المكتملة وحدها، فلا يُراجَع ما لم
// يُتلقَّ بعد. وكل نص فيها منقول من ملف الحديث كما هو: الغريب وبيانه
// بإحالته، وكلمات المتن بضبطها، ومواقف الإسقاط بخياراتها وتغذيتها الراجعة.
//
// لكل بطاقة معرّف ثابت (id) يُبنى عليه سجل الحصة اليومية في daily_review.dart:
// المادة الكاملة تُبنى هنا، ثم تُقصَر على حصة اليوم بـ limitedTo.

import 'package:flutter/foundation.dart';

import '../../hadith/data/models/models.dart';
import '../../hadith/domain/hadith_bundle.dart';
import '../../hadith/domain/practice_engine.dart';

/// بطاقة غريب.
@immutable
class GharibCard {
  const GharibCard({
    required this.hadithId,
    required this.hadithTitle,
    required this.index,
    required this.headword,
    required this.meaning,
    required this.citation,
  });

  /// الحديث.
  final String hadithId;

  /// موضع اللفظة في غريب الحديث.
  final int index;

  /// معرّف البطاقة الثابت.
  String get id => 'g|$hadithId|$index';

  /// عنوان الحديث.
  final String hadithTitle;

  /// اللفظة كما في ملف الحديث.
  final String headword;

  /// البيان.
  final String meaning;

  /// إحالة البيان إلى مصدره.
  final String citation;
}

/// تحدي ترتيب عبارات متجاورة من المتن المشكول.
@immutable
class OrderChallenge {
  const OrderChallenge({
    required this.hadithId,
    required this.hadithTitle,
    required this.drill,
  });

  /// الحديث.
  final String hadithId;

  /// عنوان الحديث.
  final String hadithTitle;

  /// العبارات وبلاطاتها المبعثرة.
  final ChunkDrill drill;

  /// معرّف البطاقة الثابت.
  String get id => 'o|$hadithId|${drill.id}';

  /// عنوان التمرين.
  String get label => drill.label;
}

/// موقف تثبيتي.
@immutable
class ScenarioCard {
  const ScenarioCard({
    required this.hadithId,
    required this.hadithTitle,
    required this.scenario,
  });

  /// الحديث.
  final String hadithId;

  /// عنوان الحديث.
  final String hadithTitle;

  /// الموقف بخياراته.
  final Scenario scenario;

  /// معرّف البطاقة الثابت.
  String get id => 's|$hadithId';
}

/// مادة المراجعة كلها.
@immutable
class ReviewDeck {
  const ReviewDeck({
    required this.hadithCount,
    required this.cardIds,
    required this.flashcards,
    required this.orderChallenges,
    required this.scenarios,
  });

  /// لا أوراد مكتملة بعد.
  static const ReviewDeck empty = ReviewDeck(
    hadithCount: 0,
    cardIds: <String>[],
    flashcards: <GharibCard>[],
    orderChallenges: <OrderChallenge>[],
    scenarios: <ScenarioCard>[],
  );

  /// عدد الأحاديث المكتملة الداخلة في المراجعة. للمنطق وحده (هل من وِرد مكتمل)؛
  /// لا يُعرض في الواجهة.
  final int hadithCount;

  /// معرّفات كل البطاقات بترتيب المنهج: حديثاً حديثاً، وفي كل حديث الغريب
  /// فمقاطع الترتيب فالموقف.
  final List<String> cardIds;

  /// بطاقات الغريب.
  final List<GharibCard> flashcards;

  /// تحديات الترتيب.
  final List<OrderChallenge> orderChallenges;

  /// المواقف.
  final List<ScenarioCard> scenarios;

  /// هل لا شيء يُراجع.
  bool get isEmpty => hadithCount == 0;

  /// عدد البطاقات في هذه المادة. بعد القصر على حصة اليوم لا يتجاوز سقفها.
  int get cardCount => flashcards.length + orderChallenges.length + scenarios.length;

  /// المادة مقصورة على البطاقات المذكورة، بترتيبها الأصلي.
  ReviewDeck limitedTo(Iterable<String> ids) {
    final Set<String> keep = ids.toSet();
    return ReviewDeck(
      hadithCount: hadithCount,
      cardIds: List<String>.unmodifiable(<String>[
        for (final String id in cardIds)
          if (keep.contains(id)) id,
      ]),
      flashcards: List<GharibCard>.unmodifiable(<GharibCard>[
        for (final GharibCard card in flashcards)
          if (keep.contains(card.id)) card,
      ]),
      orderChallenges: List<OrderChallenge>.unmodifiable(<OrderChallenge>[
        for (final OrderChallenge challenge in orderChallenges)
          if (keep.contains(challenge.id)) challenge,
      ]),
      scenarios: List<ScenarioCard>.unmodifiable(<ScenarioCard>[
        for (final ScenarioCard card in scenarios)
          if (keep.contains(card.id)) card,
      ]),
    );
  }
}

/// يبني مادة المراجعة من حزم الأحاديث المكتملة بترتيب المنهج.
ReviewDeck buildReviewDeck(List<HadithBundle> bundles, {required int seed}) {
  final List<String> ids = <String>[];
  final List<GharibCard> cards = <GharibCard>[];
  final List<OrderChallenge> challenges = <OrderChallenge>[];
  final List<ScenarioCard> scenarios = <ScenarioCard>[];
  for (final HadithBundle bundle in bundles) {
    final HadithDailyModel hadith = bundle.hadith;
    for (int i = 0; i < hadith.matn.gharib.length; i++) {
      final GharibEntry entry = hadith.matn.gharib[i];
      final GharibCard card = GharibCard(
        hadithId: hadith.id,
        hadithTitle: hadith.title,
        index: i,
        headword: entry.headword,
        meaning: entry.meaning,
        citation: entry.sources.isEmpty ? '' : bundle.citation(entry.sources.first),
      );
      cards.add(card);
      ids.add(card.id);
    }
    final PracticeEngine engine = PracticeEngine.fromHadith(hadith, seed: seed);
    for (final ChunkDrill drill in engine.drills) {
      final OrderChallenge challenge =
          OrderChallenge(hadithId: hadith.id, hadithTitle: hadith.title, drill: drill);
      challenges.add(challenge);
      ids.add(challenge.id);
    }
    final ScenarioCard scenario =
        ScenarioCard(hadithId: hadith.id, hadithTitle: hadith.title, scenario: hadith.reflection.scenario);
    scenarios.add(scenario);
    ids.add(scenario.id);
  }
  return ReviewDeck(
    hadithCount: bundles.length,
    cardIds: List<String>.unmodifiable(ids),
    flashcards: List<GharibCard>.unmodifiable(cards),
    orderChallenges: List<OrderChallenge>.unmodifiable(challenges),
    scenarios: List<ScenarioCard>.unmodifiable(scenarios),
  );
}
