// متحكم التلاوة والتتبع الصوتي التزامني: يبث تلاوة القارئ المتقن من شبكة
// توزيع المحتوى مع تخزينها مؤقتاً، ويضيء الكلمة الجارية من توقيتات AudioSync،
// ويشغل مقطع حفظ بعينه في التلقين بالترديد.
//
// المتن لا يُسمع إلا من تسجيل قارئ (AudioStatus.recorded أو aligned)؛ وما لم
// يُسجَّل بعد لا يُجلب له شيء ولا يُستبدل بصوت آلي.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../core/config/app_config.dart';
import '../../hadith/application/hadith_providers.dart';
import '../../hadith/data/models/models.dart';

/// توافر التلاوة.
enum RecitationAvailability {
  /// لم يُسجَّل المتن بعد.
  notRecorded,

  /// مسجل دون توقيتات كلمات.
  recorded,

  /// مسجل ومتزامن كلمةً كلمة.
  aligned,
}

/// حالة التلاوة.
@immutable
class RecitationState {
  const RecitationState({
    required this.availability,
    required this.phase,
    required this.playing,
    this.failure,
    this.reciter,
    this.activeSegmentId,
    this.activeTokenIndex,
  });

  /// التوافر.
  final RecitationAvailability availability;

  /// مرحلة المشغل (جلب، تخزين مؤقت، تشغيل...).
  final AudioPhase phase;

  /// هل التلاوة جارية بطلب المستخدم.
  final bool playing;

  /// سبب آخر تعذر في الجلب، أو null.
  final AudioFailureKind? failure;

  /// القارئ.
  final String? reciter;

  /// المقطع الجاري.
  final String? activeSegmentId;

  /// الكلمة الجارية.
  final int? activeTokenIndex;

  /// هل يمكن التشغيل.
  bool get canPlay =>
      availability == RecitationAvailability.recorded || availability == RecitationAvailability.aligned;

  /// هل يمكن تشغيل مقطع بعينه.
  bool get canPlayChunks => availability == RecitationAvailability.aligned && failure == null;

  /// هل يُجلب المقطع أو يُخزَّن مؤقتاً الآن.
  bool get isBusy => phase == AudioPhase.loading || phase == AudioPhase.buffering;

  /// نسخة معدلة.
  RecitationState copyWith({
    AudioPhase? phase,
    bool? playing,
    AudioFailureKind? failure,
    bool clearFailure = false,
    String? activeSegmentId,
    int? activeTokenIndex,
    bool clearActive = false,
  }) {
    return RecitationState(
      availability: availability,
      phase: phase ?? this.phase,
      playing: playing ?? this.playing,
      failure: clearFailure ? null : (failure ?? this.failure),
      reciter: reciter,
      activeSegmentId: clearActive ? null : (activeSegmentId ?? this.activeSegmentId),
      activeTokenIndex: clearActive ? null : (activeTokenIndex ?? this.activeTokenIndex),
    );
  }
}

/// المتحكم.
class RecitationController extends Notifier<RecitationState> {
  RecitationController(this.hadithId);

  /// الحديث.
  final String hadithId;

  AudioSync? _audio;
  AudioPlayerService? _player;
  StreamSubscription<Duration>? _position;
  StreamSubscription<AudioPhase>? _phase;
  int _offsetMs = 0;

  @override
  RecitationState build() {
    ref.onDispose(_release);
    final HadithDailyModel? hadith = ref.watch(hadithProvider(hadithId)).value;
    final AudioSync? audio = hadith?.matn.audio;
    _audio = audio;
    final RecitationAvailability availability;
    if (audio == null || audio.status == AudioStatus.notRecorded) {
      availability = RecitationAvailability.notRecorded;
    } else if (audio.status == AudioStatus.aligned && audio.timings.isNotEmpty) {
      availability = RecitationAvailability.aligned;
    } else {
      availability = RecitationAvailability.recorded;
    }
    return RecitationState(
      availability: availability,
      phase: AudioPhase.idle,
      playing: false,
      reciter: audio?.reciter,
    );
  }

  /// رابط التلاوة: رابط الحديث إن وُجد، وإلا قالب CDN في إعدادات التطبيق.
  Uri get audioUrl {
    final String? override = _audio?.remoteUrl;
    if (override != null && override.isNotEmpty) {
      return Uri.parse(override);
    }
    return ref.read(appConfigProvider).audioUrlFor(hadithId);
  }

  /// يشغل التلاوة كاملة.
  Future<bool> playAll() async {
    final AudioPlayerService? player = await _ensureLoaded();
    if (player == null || !ref.mounted) {
      return false;
    }
    _offsetMs = 0;
    state = state.copyWith(playing: true, clearActive: true);
    await player.playAll();
    if (ref.mounted) {
      state = state.copyWith(playing: false, clearActive: true);
    }
    return true;
  }

  /// يشغل مقطع حفظ إن كانت التوقيتات متاحة.
  Future<bool> playChunk(PracticeChunk chunk) async {
    final AudioSync? audio = _audio;
    if (!state.canPlayChunks || audio == null) {
      return false;
    }
    final WordTiming? first = _timingFor(audio, chunk.segmentId, chunk.startToken);
    final WordTiming? last = _timingFor(audio, chunk.segmentId, chunk.endToken);
    if (first == null || last == null || last.endMs <= first.startMs) {
      return false;
    }
    final AudioPlayerService? player = await _ensureLoaded();
    if (player == null || !ref.mounted) {
      return false;
    }
    _offsetMs = first.startMs;
    state = state.copyWith(playing: true, clearActive: true);
    await player.playRange(
      start: Duration(milliseconds: first.startMs),
      end: Duration(milliseconds: last.endMs),
    );
    if (ref.mounted) {
      state = state.copyWith(playing: false, clearActive: true);
    }
    return true;
  }

  /// مدة مقطع الحفظ في التسجيل، أو null.
  Duration? chunkDuration(PracticeChunk chunk) {
    final AudioSync? audio = _audio;
    if (audio == null) {
      return null;
    }
    final WordTiming? first = _timingFor(audio, chunk.segmentId, chunk.startToken);
    final WordTiming? last = _timingFor(audio, chunk.segmentId, chunk.endToken);
    if (first == null || last == null) {
      return null;
    }
    return Duration(milliseconds: last.endMs - first.startMs);
  }

  /// يوقف التشغيل.
  Future<void> stop() async {
    await _player?.stop();
    if (ref.mounted) {
      state = state.copyWith(playing: false, clearActive: true);
    }
  }

  /// يمسح سبب التعذر ويعيد المحاولة بالتشغيل.
  Future<bool> retry() async {
    state = state.copyWith(clearFailure: true);
    return playAll();
  }

  Future<AudioPlayerService?> _ensureLoaded() async {
    if (!state.canPlay) {
      return null;
    }
    final AudioPlayerService player = _player ??= ref.read(audioPlayerFactoryProvider)();
    _phase ??= player.phaseStream.listen(_onPhase);
    _position ??= player.positionStream.listen(_onPosition);
    state = state.copyWith(phase: AudioPhase.loading, clearFailure: true);
    try {
      await player.load(audioUrl, timeout: ref.read(appConfigProvider).audioLoadTimeout);
    } on AudioLoadException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(phase: AudioPhase.idle, playing: false, failure: error.kind);
      }
      return null;
    }
    if (!ref.mounted) {
      return null;
    }
    if (state.phase == AudioPhase.loading) {
      state = state.copyWith(phase: AudioPhase.ready);
    }
    return player;
  }

  void _onPhase(AudioPhase phase) {
    if (!ref.mounted || phase == state.phase) {
      return;
    }
    state = state.copyWith(phase: phase);
  }

  void _onPosition(Duration position) {
    final AudioSync? audio = _audio;
    if (!ref.mounted || audio == null || !state.playing || audio.timings.isEmpty) {
      return;
    }
    final int ms = position.inMilliseconds + _offsetMs;
    for (final WordTiming timing in audio.timings) {
      if (ms >= timing.startMs && ms < timing.endMs) {
        if (timing.segmentId != state.activeSegmentId || timing.tokenIndex != state.activeTokenIndex) {
          state = state.copyWith(
            activeSegmentId: timing.segmentId,
            activeTokenIndex: timing.tokenIndex,
          );
        }
        return;
      }
    }
  }

  WordTiming? _timingFor(AudioSync audio, String segmentId, int tokenIndex) {
    for (final WordTiming timing in audio.timings) {
      if (timing.segmentId == segmentId && timing.tokenIndex == tokenIndex) {
        return timing;
      }
    }
    return null;
  }

  void _release() {
    unawaited(_position?.cancel());
    unawaited(_phase?.cancel());
    _position = null;
    _phase = null;
    final AudioPlayerService? player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose());
    }
  }
}

/// تلاوة حديث.
final NotifierProviderFamily<RecitationController, RecitationState, String>
    recitationControllerProvider =
    NotifierProvider.autoDispose.family<RecitationController, RecitationState, String>(
  RecitationController.new,
);
