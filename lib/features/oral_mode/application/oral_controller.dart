// متحكم مجلس السماع والمشافهة: السرد القصصي، والتلقين بالترديد، والمأزق الصوتي.
//
// - السرد والمأزق: بصوت آلي من نصوص المنصة فقط، أو بعرض الجمل مكبّرة بالتتابع
//   إن لم يتوفر صوت عربي.
// - التلقين: المتن يُسمع من تسجيل القارئ وحده؛ فإن لم يُسجَّل بعد يُعرض المقطع
//   مكبّراً مع عدّ هادئ يردده المستخدم بصوته ثلاث مرات. لا يُقرأ المتن آلياً.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/audio/speech_service.dart';
import '../../../core/storage/key_value_store.dart';
import '../../hadith/application/content_providers.dart';
import '../../hadith/data/models/models.dart';
import '../../journey/application/journey_controller.dart';
import '../../recitation/application/recitation_controller.dart';
import '../domain/oral_script.dart';

/// خطوات المجلس.
enum OralStep {
  /// السرد القصصي للسياق.
  story('القصة'),

  /// التلقين بالترديد.
  talqin('التلقين'),

  /// المأزق الصوتي.
  dilemma('المأزق');

  const OralStep(this.label);

  /// العنوان.
  final String label;
}

/// طور التلقين.
enum TalqinPhase {
  /// لم يبدأ.
  idle,

  /// يستمع إلى القارئ.
  listening,

  /// يردد المستخدم.
  repeating,

  /// استراحة قصيرة بين الجولات.
  resting,

  /// اكتملت المقاطع.
  done,
}

/// حالة المجلس.
@immutable
class OralState {
  const OralState({
    required this.step,
    required this.playing,
    required this.caption,
    required this.captionIndex,
    required this.captionCount,
    required this.voiceAvailable,
    required this.pace,
    required this.chunkIndex,
    required this.round,
    required this.phase,
    required this.secondsLeft,
    required this.chosenOptionId,
    required this.visited,
    required this.finished,
  });

  /// البداية.
  factory OralState.initial(SpeechPace pace) {
    return OralState(
      step: OralStep.story,
      playing: false,
      caption: '',
      captionIndex: 0,
      captionCount: 0,
      voiceAvailable: null,
      pace: pace,
      chunkIndex: 0,
      round: 0,
      phase: TalqinPhase.idle,
      secondsLeft: 0,
      chosenOptionId: null,
      visited: const <OralStep>{OralStep.story},
      finished: false,
    );
  }

  /// عدد جولات الترديد لكل مقطع.
  static const int rounds = 3;

  /// الخطوة.
  final OralStep step;

  /// هل يعمل السرد أو التلقين.
  final bool playing;

  /// الجملة المعروضة الآن.
  final String caption;

  /// رقمها.
  final int captionIndex;

  /// عدد الجمل.
  final int captionCount;

  /// هل الصوت العربي متوفر (null قبل الفحص).
  final bool? voiceAvailable;

  /// السرعة.
  final SpeechPace pace;

  /// مقطع التلقين.
  final int chunkIndex;

  /// الجولة الحالية (١ - ٣).
  final int round;

  /// الطور.
  final TalqinPhase phase;

  /// العد التنازلي لطور الترديد.
  final int secondsLeft;

  /// الخيار المختار في المأزق.
  final String? chosenOptionId;

  /// الخطوات المزارة.
  final Set<OralStep> visited;

  /// هل اكتمل المجلس.
  final bool finished;

  /// يمكن الإتمام بعد الاختيار في المأزق.
  bool get canFinish => chosenOptionId != null;

  /// نسخة معدلة.
  OralState copyWith({
    OralStep? step,
    bool? playing,
    String? caption,
    int? captionIndex,
    int? captionCount,
    bool? voiceAvailable,
    SpeechPace? pace,
    int? chunkIndex,
    int? round,
    TalqinPhase? phase,
    int? secondsLeft,
    String? chosenOptionId,
    Set<OralStep>? visited,
    bool? finished,
  }) {
    return OralState(
      step: step ?? this.step,
      playing: playing ?? this.playing,
      caption: caption ?? this.caption,
      captionIndex: captionIndex ?? this.captionIndex,
      captionCount: captionCount ?? this.captionCount,
      voiceAvailable: voiceAvailable ?? this.voiceAvailable,
      pace: pace ?? this.pace,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      round: round ?? this.round,
      phase: phase ?? this.phase,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      chosenOptionId: chosenOptionId ?? this.chosenOptionId,
      visited: visited ?? this.visited,
      finished: finished ?? this.finished,
    );
  }
}

/// المتحكم.
class OralController extends Notifier<OralState> {
  OralController(this.hadithId);

  /// الحديث.
  final String hadithId;

  HadithDailyModel? _hadith;
  int _session = 0;

  @override
  OralState build() {
    final SpeechService speech = ref.read(speechServiceProvider);
    ref.onDispose(() {
      _session++;
      unawaited(speech.stop());
    });
    _hadith = ref.watch(hadithProvider(hadithId)).value;
    final String? stored = ref.read(keyValueStoreProvider).readString(StorageKeys.oralPace);
    return OralState.initial(SpeechPace.fromWire(stored));
  }

  SpeechService get _speech => ref.read(speechServiceProvider);

  RecitationController get _recitation => ref.read(recitationControllerProvider(hadithId).notifier);

  bool _alive(int token) => ref.mounted && token == _session;

  int _begin() {
    _session++;
    unawaited(_speech.stop());
    unawaited(_recitation.stop());
    return _session;
  }

  /// مقاطع التلقين.
  List<PracticeChunk> get chunks => _hadith?.practice.chunks ?? const <PracticeChunk>[];

  /// نص المقطع الحالي للعرض.
  String get currentChunkText {
    final HadithDailyModel? hadith = _hadith;
    final List<PracticeChunk> list = chunks;
    if (hadith == null || list.isEmpty) {
      return '';
    }
    final int index = state.chunkIndex >= list.length ? list.length - 1 : state.chunkIndex;
    return chunkDisplayText(hadith, list[index]);
  }

  /// اختيار خطوة.
  void selectStep(OralStep step) {
    _begin();
    state = state.copyWith(
      step: step,
      playing: false,
      caption: '',
      captionIndex: 0,
      captionCount: 0,
      phase: TalqinPhase.idle,
      round: 0,
      secondsLeft: 0,
      visited: <OralStep>{...state.visited, step},
    );
  }

  /// تغيير السرعة وحفظها.
  void setPace(SpeechPace pace) {
    state = state.copyWith(pace: pace);
    unawaited(ref.read(keyValueStoreProvider).writeString(StorageKeys.oralPace, pace.wire));
  }

  /// إيقاف كل صوت.
  void stop() {
    _begin();
    state = state.copyWith(
      playing: false,
      phase: state.phase == TalqinPhase.done ? TalqinPhase.done : TalqinPhase.idle,
      secondsLeft: 0,
    );
  }

  /// السرد القصصي.
  Future<void> playStory() async {
    final HadithDailyModel? hadith = _hadith;
    if (hadith == null) {
      return;
    }
    final int token = _begin();
    state = state.copyWith(step: OralStep.story, playing: true);
    await _narrate(token, storyLines(hadith));
    if (_alive(token)) {
      state = state.copyWith(playing: false);
    }
  }

  /// عرض المأزق صوتياً.
  Future<void> playDilemma() async {
    final HadithDailyModel? hadith = _hadith;
    if (hadith == null) {
      return;
    }
    final int token = _begin();
    state = state.copyWith(step: OralStep.dilemma, playing: true);
    await _narrate(token, dilemmaLines(hadith.reflection.scenario));
    if (_alive(token)) {
      state = state.copyWith(playing: false);
    }
  }

  /// اختيار في المأزق ثم سماع التغذية والعلة.
  Future<void> choose(String optionId) async {
    final HadithDailyModel? hadith = _hadith;
    if (hadith == null) {
      return;
    }
    final Scenario scenario = hadith.reflection.scenario;
    ScenarioOption? option;
    for (final ScenarioOption candidate in scenario.options) {
      if (candidate.id == optionId) {
        option = candidate;
      }
    }
    if (option == null) {
      return;
    }
    final int token = _begin();
    state = state.copyWith(chosenOptionId: optionId, playing: true);
    await _narrate(token, feedbackLines(option, scenario));
    if (_alive(token)) {
      state = state.copyWith(playing: false);
    }
  }

  /// التلقين بالترديد من المقطع الحالي إلى آخر المقاطع.
  Future<void> startTalqin() async {
    final List<PracticeChunk> list = chunks;
    if (list.isEmpty) {
      return;
    }
    final int token = _begin();
    state = state.copyWith(step: OralStep.talqin, playing: true);
    for (int k = state.chunkIndex; k < list.length; k++) {
      if (!_alive(token)) {
        return;
      }
      state = state.copyWith(chunkIndex: k);
      for (int round = 1; round <= OralState.rounds; round++) {
        if (!_alive(token)) {
          return;
        }
        final PracticeChunk chunk = list[k];
        Duration repeatFor = _readingTime(chunk);
        state = state.copyWith(round: round, phase: TalqinPhase.listening, secondsLeft: 0);
        final bool played = await _recitation.playChunk(chunk);
        if (!_alive(token)) {
          return;
        }
        if (played) {
          final Duration? heard = _recitation.chunkDuration(chunk);
          if (heard != null) {
            repeatFor = heard * 1.25;
          }
        }
        await _countdown(token, repeatFor);
        if (!_alive(token)) {
          return;
        }
        state = state.copyWith(phase: TalqinPhase.resting, secondsLeft: 0);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
    if (_alive(token)) {
      state = state.copyWith(playing: false, phase: TalqinPhase.done, secondsLeft: 0);
    }
  }

  /// الانتقال يدوياً بين مقاطع التلقين.
  void moveChunk(int delta) {
    final int target = state.chunkIndex + delta;
    if (target < 0 || target >= chunks.length) {
      return;
    }
    _begin();
    state = state.copyWith(
      chunkIndex: target,
      playing: false,
      phase: TalqinPhase.idle,
      round: 0,
      secondsLeft: 0,
    );
  }

  /// إتمام المجلس، ويُسجَّل وِرداً إن كان وِرد اليوم.
  Future<void> finish({required bool countsTowardJourney}) async {
    if (state.finished || !state.canFinish) {
      return;
    }
    _begin();
    if (countsTowardJourney) {
      await ref.read(journeyControllerProvider.notifier).completeWird(hadithId);
    }
    if (ref.mounted) {
      state = state.copyWith(finished: true, playing: false);
    }
  }

  Future<void> _narrate(int token, List<String> lines) async {
    final bool voice = await _speech.prepareArabic();
    if (!_alive(token)) {
      return;
    }
    state = state.copyWith(voiceAvailable: voice, captionCount: lines.length);
    for (int i = 0; i < lines.length; i++) {
      if (!_alive(token)) {
        return;
      }
      state = state.copyWith(caption: lines[i], captionIndex: i);
      if (voice) {
        await _speech.speak(speechSafe(lines[i]), pace: state.pace);
      } else {
        await Future<void>.delayed(_captionTime(lines[i]));
      }
    }
  }

  Future<void> _countdown(int token, Duration total) async {
    int seconds = (total.inMilliseconds / 1000).ceil();
    if (seconds < 3) {
      seconds = 3;
    }
    for (int left = seconds; left > 0; left--) {
      if (!_alive(token)) {
        return;
      }
      state = state.copyWith(phase: TalqinPhase.repeating, secondsLeft: left);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Duration _captionTime(String line) {
    final double factor = state.pace == SpeechPace.slow ? 1.4 : 1.0;
    final int ms = (line.length * 75 * factor).round();
    return Duration(milliseconds: ms < 2400 ? 2400 : ms);
  }

  Duration _readingTime(PracticeChunk chunk) {
    final double perWord = state.pace == SpeechPace.slow ? 1300 : 950;
    return Duration(milliseconds: (chunk.tokenCount * perWord).round() + 1500);
  }
}

/// مجلس حديث.
final NotifierProviderFamily<OralController, OralState, String> oralControllerProvider =
    NotifierProvider.autoDispose.family<OralController, OralState, String>(
  OralController.new,
);
