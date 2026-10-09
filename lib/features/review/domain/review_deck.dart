// مادة ميدان المراجعة: تُبنى من الأوراد المكتملة وحدها، فلا يُراجَع ما لم
// يُتلقَّ بعد. وكل نص فيها منقول من ملف الحديث كما هو: الغريب وبيانه
// بإحالته، وكلمات المتن بضبطها، ومواقف الإسقاط بخياراتها وتغذيتها الراجعة.

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
    required this.headword,
    required this.meaning,
    required this.citation,
  });

  /// الحديث.
  final String hadithId;

  /// عنوان الحديث.
  final String hadithTitle;

  /// اللفظة كما في ملف الحديث.
  final String headword;

  /// البيان.
  final String meaning;

  /// إحالة البيان إلى مصدره.
  final String citation;
}

/// تحدي ترتيب كلمات مقطع من المتن المشكول.
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

  /// المقطع وبلاطاته المبعثرة.
  final ChunkDrill drill;

  /// عنوان المقطع.
  String get label => drill.chunk.label;
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
}

/// مادة المراجعة كلها.
@immutable
class ReviewDeck {
  const ReviewDeck({
    required this.hadithCount,
    required this.flashcards,
    required this.orderChallenges,
    required this.scenarios,
  });

  /// لا أوراد مكتملة بعد.
  static const ReviewDeck empty = ReviewDeck(
    hadithCount: 0,
    flashcards: <GharibCard>[],
    orderChallenges: <OrderChallenge>[],
    scenarios: <ScenarioCard>[],
  );

  /// عدد الأحاديث المكتملة الداخلة في المراجعة.
  final int hadithCount;

  /// بطاقات الغريب.
  final List<GharibCard> flashcards;

  /// تحديات الترتيب.
  final List<OrderChallenge> orderChallenges;

  /// المواقف.
  final List<ScenarioCard> scenarios;

  /// هل لا شيء يُراجع.
  bool get isEmpty => hadithCount == 0;
}

/// يبني مادة المراجعة من حزم الأحاديث المكتملة بترتيب المنهج.
ReviewDeck buildReviewDeck(List<HadithBundle> bundles, {required int seed}) {
  final List<GharibCard> cards = <GharibCard>[];
  final List<OrderChallenge> challenges = <OrderChallenge>[];
  final List<ScenarioCard> scenarios = <ScenarioCard>[];
  for (final HadithBundle bundle in bundles) {
    final HadithDailyModel hadith = bundle.hadith;
    for (final GharibEntry entry in hadith.matn.gharib) {
      cards.add(
        GharibCard(
          hadithId: hadith.id,
          hadithTitle: hadith.title,
          headword: entry.headword,
          meaning: entry.meaning,
          citation: entry.sources.isEmpty ? '' : bundle.citation(entry.sources.first),
        ),
      );
    }
    final PracticeEngine engine = PracticeEngine.fromHadith(hadith, seed: seed);
    for (final ChunkDrill drill in engine.drills) {
      challenges.add(OrderChallenge(hadithId: hadith.id, hadithTitle: hadith.title, drill: drill));
    }
    scenarios.add(
      ScenarioCard(hadithId: hadith.id, hadithTitle: hadith.title, scenario: hadith.reflection.scenario),
    );
  }
  return ReviewDeck(
    hadithCount: bundles.length,
    flashcards: List<GharibCard>.unmodifiable(cards),
    orderChallenges: List<OrderChallenge>.unmodifiable(challenges),
    scenarios: List<ScenarioCard>.unmodifiable(scenarios),
  );
}
