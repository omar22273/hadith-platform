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

  /// الانتقال إلى مرحلة.
  void goTo(SessionStage stage) {
    if (state.finished) {
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

  /// اختيار مقطع ترصيع.
  void selectDrill(int index) {
    final PracticeEngine? engine = _engine;
    if (engine == null || index < 0 || index >= engine.drills.length) {
      return;
    }
    state = state.copyWith(drillIndex: index, placedTiles: const <int>[], clearMistake: true);
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
      state = state.copyWith(mistakeTileId: tileId, mistakeTick: state.mistakeTick + 1);
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

  /// المقطع التالي.
  void nextDrill() {
    selectDrill(state.drillIndex + 1);
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
