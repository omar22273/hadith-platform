// مزودات ميدان المراجعة: مادة المراجعة من الأوراد المكتملة، ومتحكمات
// الجلسات الثلاث (البطاقات، والترتيب، والمواقف).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/asset_json_source.dart';
import '../../../core/storage/install_salt.dart';
import '../../../core/text/stable_hash.dart';
import '../../hadith/application/hadith_providers.dart';
import '../../hadith/data/models/models.dart';
import '../../hadith/domain/hadith_bundle.dart';
import '../../journey/application/journey_progress_controller.dart';
import '../../journey/domain/journey_progress.dart';
import '../domain/review_deck.dart';
import '../domain/review_sessions.dart';

/// الأقسام الثلاثة للميدان.
enum ReviewMode {
  /// بطاقات غريب الألفاظ.
  flashcards('بطاقات الغريب'),

  /// ترتيب كلمات المتن.
  wordOrder('ترتيب المتن'),

  /// مواقف التثبيت.
  scenarios('مواقف التثبيت');

  const ReviewMode(this.label);

  /// الاسم المعروض.
  final String label;
}

/// مادة المراجعة من الأوراد المكتملة بترتيب المنهج.
final FutureProvider<ReviewDeck> reviewDeckProvider = FutureProvider<ReviewDeck>(
  (Ref ref) async {
    final JourneyProgress progress = await ref.watch(journeyProgressProvider.future);
    final CurriculumManifest curriculum = await ref.watch(curriculumProvider.future);
    final List<HadithBundle> bundles = <HadithBundle>[];
    for (final CurriculumItem item in curriculum.items) {
      if (progress.isCompleted(item.hadithId)) {
        bundles.add(await ref.watch(hadithBundleProvider(item.hadithId).future));
      }
    }
    if (bundles.isEmpty) {
      return ReviewDeck.empty;
    }
    final int seed = stableHash('review|${ref.watch(installSaltProvider)}|${progress.completed.length}');
    return buildReviewDeck(bundles, seed: seed);
  },
  retry: contentNoRetry,
);

/// متحكم القسم المختار.
class ReviewModeController extends Notifier<ReviewMode> {
  @override
  ReviewMode build() => ReviewMode.flashcards;

  /// يختار قسماً.
  void select(ReviewMode mode) {
    state = mode;
  }
}

/// القسم المختار.
final NotifierProvider<ReviewModeController, ReviewMode> reviewModeProvider =
    NotifierProvider<ReviewModeController, ReviewMode>(ReviewModeController.new);

/// متحكم جلسة البطاقات.
class FlashcardSessionController extends Notifier<FlashcardSession> {
  @override
  FlashcardSession build() {
    final ReviewDeck? deck = ref.watch(reviewDeckProvider).value;
    return FlashcardSession.start(deck?.flashcards.length ?? 0);
  }

  /// يقلب البطاقة.
  void flip() => state = state.flip();

  /// «عرفتُها».
  void markKnown() => state = state.markKnown();

  /// «أعدها لاحقاً».
  void repeatLater() => state = state.repeatLater();

  /// يبدأ الجلسة من جديد.
  void restart() {
    final ReviewDeck? deck = ref.read(reviewDeckProvider).value;
    state = FlashcardSession.start(deck?.flashcards.length ?? 0);
  }
}

/// جلسة البطاقات.
final NotifierProvider<FlashcardSessionController, FlashcardSession> flashcardSessionProvider =
    NotifierProvider<FlashcardSessionController, FlashcardSession>(FlashcardSessionController.new);

/// حالة تحديات الترتيب: التحدي المختار ولوحته والمقاطع المكتملة.
class OrderChallengeState {
  const OrderChallengeState({
    required this.index,
    required this.board,
    required this.lastOutcome,
    this.completed = const <int>{},
  });

  /// التحدي المختار.
  final int index;

  /// اللوحة، أو null إن لم توجد تحديات.
  final OrderBoard? board;

  /// نتيجة آخر محاولة.
  final PlacementOutcome? lastOutcome;

  /// رتب المقاطع التي اكتمل ترتيبها بنجاح.
  final Set<int> completed;
}

/// متحكم تحديات الترتيب.
class OrderChallengeController extends Notifier<OrderChallengeState> {
  @override
  OrderChallengeState build() {
    final ReviewDeck? deck = ref.watch(reviewDeckProvider).value;
    return _stateFor(deck, 0, const <int>{});
  }

  OrderChallengeState _stateFor(ReviewDeck? deck, int index, Set<int> completed) {
    if (deck == null || deck.orderChallenges.isEmpty) {
      return const OrderChallengeState(index: 0, board: null, lastOutcome: null);
    }
    final int bounded = index < 0 ? 0 : (index >= deck.orderChallenges.length ? deck.orderChallenges.length - 1 : index);
    return OrderChallengeState(
      index: bounded,
      board: OrderBoard.start(deck.orderChallenges[bounded].drill),
      lastOutcome: null,
      completed: completed,
    );
  }

  /// أعلى مقطع مفتوح الآن.
  int get openLimit {
    final ReviewDeck? deck = ref.read(reviewDeckProvider).value;
    return openChallengeLimit(state.completed, deck?.orderChallenges.length ?? 0);
  }

  /// يضع بلاطة في الموضع التالي.
  PlacementOutcome place(int tileId) {
    final OrderBoard? board = state.board;
    if (board == null) {
      return PlacementOutcome.ignored;
    }
    final (OrderBoard next, PlacementOutcome outcome) = board.place(tileId);
    state = OrderChallengeState(
      index: state.index,
      board: next,
      lastOutcome: outcome,
      completed: outcome == PlacementOutcome.completed
          ? Set<int>.unmodifiable(<int>{...state.completed, state.index})
          : state.completed,
    );
    return outcome;
  }

  /// يتراجع عن آخر كلمة.
  void undo() {
    final OrderBoard? board = state.board;
    if (board == null) {
      return;
    }
    state = OrderChallengeState(
      index: state.index,
      board: board.undo(),
      lastOutcome: null,
      completed: state.completed,
    );
  }

  /// يعيد المقطع الحالي (ويبقى مفتوحاً ما اكتمل قبلاً).
  void reset() {
    state = _stateFor(ref.read(reviewDeckProvider).value, state.index, state.completed);
  }

  /// ينتقل إلى تحدٍّ مفتوح. المقاطع اللاحقة المقفلة لا تُفتح بالنقر.
  void select(int index) {
    if (index > openLimit) {
      return;
    }
    state = _stateFor(ref.read(reviewDeckProvider).value, index, state.completed);
  }
}

/// تحديات الترتيب.
final NotifierProvider<OrderChallengeController, OrderChallengeState> orderChallengeProvider =
    NotifierProvider<OrderChallengeController, OrderChallengeState>(OrderChallengeController.new);

/// متحكم المواقف.
class ScenarioQuizController extends Notifier<ScenarioQuizSession> {
  @override
  ScenarioQuizSession build() {
    ref.watch(reviewDeckProvider);
    return ScenarioQuizSession.initial;
  }

  /// يختار خياراً في الموقف الحالي.
  void choose(String optionId) => state = state.choose(optionId);

  /// ينتقل إلى موقف.
  void goTo(int index) => state = state.goTo(index);
}

/// جلسة المواقف.
final NotifierProvider<ScenarioQuizController, ScenarioQuizSession> scenarioQuizProvider =
    NotifierProvider<ScenarioQuizController, ScenarioQuizSession>(ScenarioQuizController.new);
