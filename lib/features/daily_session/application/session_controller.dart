// متحكم جلسة الوِرد: يقود محرك التنقل بين المراحل الأربع، والغريب اللمسي،
// والترصيع والتلاشي، والمأزق، ثم يسجل الإتمام في مسار القوافل.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/storage/install_salt.dart';
import '../../../core/text/stable_hash.dart';
import '../../../core/time/clock.dart';
import '../../hadith/application/hadith_providers.dart';
import '../../hadith/data/models/models.dart';
import '../../hadith/domain/practice_engine.dart';
import '../../journey/application/journey_controller.dart';
import '../../journey/application/pacing_notifier.dart';
import 'session_state.dart';

/// نتيجة وضع بلاطة.
enum PlacementResult {
  /// وُضعت في موضعها.
  placed,

  /// وُضعت واكتمل المقطع.
  completedDrill,

  /// لا توافق الموضع التالي؛ تعود بلطف لمحاولة أخرى.
  mismatch,

  /// لا أثر (بلاطة موضوعة سلفاً أو مقطع مكتمل).
  ignored,
}

/// هل أتمّ المستخدم ترصيع كل مقاطع الحديث؟ لا يُفتح ما بعد التثبيت قبل ذلك.
/// حديث بلا مقاطع ترصيع لا يحجز المستخدم؛ ومحرك لم يُبنَ بعد يُعدّ غير مكتمل.
bool isPracticeCleared(PracticeEngine? engine, Set<int> completedDrills) {
  if (engine == null) {
    return false;
  }
  for (int i = 0; i < engine.drills.length; i++) {
    if (!completedDrills.contains(i)) {
      return false;
    }
  }
  return true;
}

/// أبعد مقطع يجوز فتحه: أول مقطع لم يكتمل، أو الأخير إن اكتملت كلها.
int openDrillLimit(int drillCount, Set<int> completedDrills) {
  for (int i = 0; i < drillCount; i++) {
    if (!completedDrills.contains(i)) {
      return i;
    }
  }
  return drillCount == 0 ? 0 : drillCount - 1;
}

/// محرك التثبيت للحديث، ببذرة خاصة بالجهاز واليوم.
final ProviderFamily<PracticeEngine?, String> practiceEngineProvider =
    Provider.autoDispose.family<PracticeEngine?, String>(
  (Ref ref, String hadithId) {
    final HadithDailyModel? hadith = ref.watch(hadithProvider(hadithId)).value;
    if (hadith == null) {
      return null;
    }
    final String salt = ref.watch(installSaltProvider);
    final DateTime today = ref.read(clockProvider)();
    return PracticeEngine.fromHadith(hadith, seed: daySeed(today, '$hadithId|$salt'));
  },
);

/// هل اكتمل ترصيع كل المقاطع في جلسة هذا الحديث (تُبنى عليه أقفال التنقل).
final ProviderFamily<bool, String> practiceClearedProvider = Provider.autoDispose.family<bool, String>(
  (Ref ref, String hadithId) {
    final PracticeEngine? engine = ref.watch(practiceEngineProvider(hadithId));
    final Set<int> completed = ref.watch(
      sessionControllerProvider(hadithId).select((SessionState s) => s.completedDrills),
    );
    return isPracticeCleared(engine, completed);
  },
);

/// المتحكم.
class SessionController extends Notifier<SessionState> {
  SessionController(this.hadithId);

  /// الحديث.
  final String hadithId;

  @override
  SessionState build() {
    ref.watch(practiceEngineProvider(hadithId));
    return SessionState.initial;
  }

  PracticeEngine? get _engine => ref.read(practiceEngineProvider(hadithId));

  /// هل يجوز تجاوز مرحلة التثبيت: لا يُفتح أثر الحديث في حياتك قبل ترصيع كل المقاطع.
  bool get practiceCleared => isPracticeCleared(_engine, state.completedDrills);

  /// الانتقال إلى مرحلة. القفز إلى ما بعد التثبيت مرفوض قبل إتمام الترصيع،
  /// سواء جاء من زر «التالي» أو من لمس شريط المراحل.
  void goTo(SessionStage stage) {
    if (state.finished) {
      return;
    }
    if (stage.index > SessionStage.practice.index && !practiceCleared) {
      return;
    }
    state = state.copyWith(
      stage: stage,
      visited: <SessionStage>{...state.visited, stage},
      clearGharib: true,
    );
  }

  /// المرحلة التالية.
  void next() {
    final int index = state.stage.index;
    if (index + 1 < SessionStage.values.length) {
      goTo(SessionStage.values[index + 1]);
    }
  }

  /// المرحلة السابقة.
  void previous() {
    final int index = state.stage.index;
    if (index > 0) {
      goTo(SessionStage.values[index - 1]);
    }
  }

  /// فتح طبقة طالب العلم أو إغلاقها.
  void toggleScholarLayer() {
    state = state.copyWith(scholarLayerOpen: !state.scholarLayerOpen);
  }

  /// اختيار لفظة غريبة أو إلغاء اختيارها.
  void selectGharib(String gharibId) {
    if (state.selectedGharibId == gharibId) {
      state = state.copyWith(clearGharib: true);
    } else {
      state = state.copyWith(selectedGharibId: gharibId);
    }
  }

  /// إغلاق بطاقة الغريب.
  void clearGharib() {
    state = state.copyWith(clearGharib: true);
  }

  /// تبديل تمرين التثبيت.
  void setPracticeMode(PracticeMode mode) {
    state = state.copyWith(practiceMode: mode, clearMistake: true);
  }

  /// اختيار مقطع ترصيع. المقاطع اللاحقة لأول مقطع لم يكتمل مقفلة، والمقطع
  /// المكتمل يعود مستقراً في موضعه، ولمس المقطع الحالي لا يمحو ما رُصّع فيه.
  void selectDrill(int index) {
    final PracticeEngine? engine = _engine;
    if (engine == null || index < 0 || index >= engine.drills.length) {
      return;
    }
    if (index > openDrillLimit(engine.drills.length, state.completedDrills) || index == state.drillIndex) {
      return;
    }
    final List<int> restored =
        state.completedDrills.contains(index) ? _solvedPlacement(engine.drills[index]) : const <int>[];
    state = state.copyWith(drillIndex: index, placedTiles: restored, clearMistake: true);
  }

  /// زر «تجاوز للاختبار ⚡»: يرتّب عبارات كل التمارين ترتيباً صحيحاً ويعرض
  /// آخرها مكتملاً، فيُفتح «التالي» وما بعد التثبيت فوراً. لا يعمل إلا إذا كان
  /// وضع التجربة مفعّلاً في الإعدادات. يعيد true إن نُفّذ.
  bool skipPracticeForTesting() {
    final PracticeEngine? engine = _engine;
    if (engine == null || engine.drills.isEmpty || !ref.read(testingSkipEnabledProvider)) {
      return false;
    }
    final int last = engine.drills.length - 1;
    state = state.copyWith(
      drillIndex: last,
      placedTiles: _solvedPlacement(engine.drills[last]),
      completedDrills: <int>{for (int i = 0; i <= last; i++) i},
      clearMistake: true,
    );
    return true;
  }

  /// ترتيب البلاطات الذي يطابق المقطع تماماً (لعرض مقطع مكتمل سابقاً).
  List<int> _solvedPlacement(ChunkDrill drill) {
    final Set<int> used = <int>{};
    final List<int> order = <int>[];
    for (int position = 0; position < drill.tokens.length; position++) {
      for (final PracticeTile tile in drill.tiles) {
        if (!used.contains(tile.id) && drill.fits(tile.id, position)) {
          used.add(tile.id);
          order.add(tile.id);
          break;
        }
      }
    }
    return List<int>.unmodifiable(order);
  }

  /// هل المقطع الحالي مرتب الآن مطابقاً للمتن المشكول تماماً: كل البلاطات
  /// موضوعة، وكل واحدة في موضعها الصحيح.
  bool get currentDrillMatches {
    final PracticeEngine? engine = _engine;
    if (engine == null || engine.drills.isEmpty || state.drillIndex >= engine.drills.length) {
      return false;
    }
    final ChunkDrill drill = engine.drills[state.drillIndex];
    final List<int> placed = state.placedTiles;
    if (placed.length != drill.tokens.length) {
      return false;
    }
    for (int position = 0; position < placed.length; position++) {
      if (!drill.fits(placed[position], position)) {
        return false;
      }
    }
    return true;
  }

  /// وضع بلاطة في الحوض.
  PlacementResult placeTile(int tileId) {
    final PracticeEngine? engine = _engine;
    if (engine == null || engine.drills.isEmpty) {
      return PlacementResult.ignored;
    }
    final ChunkDrill drill = engine.drills[state.drillIndex];
    final List<int> placed = state.placedTiles;
    if (placed.contains(tileId) || placed.length >= drill.tokens.length) {
      return PlacementResult.ignored;
    }
    if (!drill.fits(tileId, placed.length)) {
      state = state.copyWith(
        mistakeTileId: tileId,
        mistakeTick: state.mistakeTick + 1,
        mistakeStreak: state.mistakeStreak + 1,
      );
      return PlacementResult.mismatch;
    }
    final List<int> updated = List<int>.unmodifiable(<int>[...placed, tileId]);
    final bool complete = updated.length == drill.tokens.length;
    state = state.copyWith(
      placedTiles: updated,
      clearMistake: true,
      completedDrills: complete
          ? <int>{...state.completedDrills, state.drillIndex}
          : state.completedDrills,
    );
    return complete ? PlacementResult.completedDrill : PlacementResult.placed;
  }

  /// إرجاع آخر بلاطة.
  void undoTile() {
    final List<int> placed = state.placedTiles;
    if (placed.isEmpty) {
      return;
    }
    state = state.copyWith(
      placedTiles: List<int>.unmodifiable(placed.sublist(0, placed.length - 1)),
      clearMistake: true,
    );
  }

  /// إعادة المقطع من أوله.
  void resetDrill() {
    state = state.copyWith(placedTiles: const <int>[], clearMistake: true);
  }

  /// المقطع التالي. لا ينتقل إلا إذا طابق المقطع الحالي المتن تماماً.
  void nextDrill() {
    if (!currentDrillMatches) {
      return;
    }
    selectDrill(state.drillIndex + 1);
  }

  /// زر «التالي ←» داخل لوحة الترصيع: إلى المقطع التالي، أو إلى المرحلة
  /// التالية بعد آخر مقطع. يتحقق من المطابقة التامة بنفسه فلا يُفلته زر مفعّل
  /// بالخطأ. يعيد هل انتقل.
  bool advanceFromDrill() {
    final PracticeEngine? engine = _engine;
    if (engine == null || !currentDrillMatches || !state.completedDrills.contains(state.drillIndex)) {
      return false;
    }
    if (state.drillIndex + 1 < engine.drills.length) {
      selectDrill(state.drillIndex + 1);
      return true;
    }
    if (!practiceCleared) {
      return false;
    }
    final SessionStage before = state.stage;
    next();
    return state.stage != before;
  }

  /// مستوى التلاشي.
  void setVanishingLevel(int level) {
    state = state.copyWith(vanishingLevel: level, revealed: const <int>{});
  }

  /// كشف كلمة مخفية بعد استحضارها.
  void reveal(int wordIndex) {
    state = state.copyWith(revealed: <int>{...state.revealed, wordIndex});
  }

  /// إخفاء ما كُشف لمحاولة جديدة.
  void hideAgain() {
    state = state.copyWith(revealed: const <int>{});
  }

  /// اختيار في المأزق؛ يجوز تغييره لقراءة تغذية الخيارات الأخرى بلا توبيخ.
  void chooseOption(String optionId) {
    state = state.copyWith(chosenOptionId: optionId);
  }

  /// يتم الوِرد. يُسجَّل في المسار إن كان وِرد اليوم لا مراجعة، ويعيد نتيجة
  /// التسجيل (null للمراجعة)، ومنها يُعرف بلوغ حصة اليوم.
  Future<WirdCompletion?> finish({required bool countsTowardJourney}) async {
    if (state.finished) {
      return null;
    }
    WirdCompletion? result;
    if (countsTowardJourney) {
      result = await ref.read(journeyControllerProvider.notifier).completeWird(hadithId);
    }
    if (ref.mounted) {
      state = state.copyWith(finished: true);
    }
    return result;
  }
}

/// جلسة حديث.
final NotifierProviderFamily<SessionController, SessionState, String> sessionControllerProvider =
    NotifierProvider.autoDispose.family<SessionController, SessionState, String>(
  SessionController.new,
);
