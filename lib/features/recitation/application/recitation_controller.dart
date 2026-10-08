// متحكم التلاوة والتتبع الصوتي التزامني: يضيء الكلمة الجارية من توقيتات
// AudioSync، ويشغل مقطع حفظ بعينه في التلقين بالترديد.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../hadith/application/content_providers.dart';
import '../../hadith/data/models/models.dart';
import '../data/recitation_player.dart';

/// توفر التلاوة.
enum RecitationAvailability {
  /// لم تُسجَّل بعد: لا صوت للمتن.
  notRecorded,

  /// مسجلة دون مزامنة كلمات.
  recorded,

  /// مسجلة ومتزامنة كلمة كلمة.
  aligned,

  /// تعذر تحميل الملف.
  unavailable,
}

/// حالة التلاوة.
@immutable
class RecitationState {
  const RecitationState({
    required this.availability,
    required this.playing,
    this.reciter,
    this.activeSegmentId,
    this.activeTokenIndex,
  });

  /// التوفر.
  final RecitationAvailability availability;

  /// هل تعمل الآن.
  final bool playing;

  /// القارئ.
  final String? reciter;

  /// مقطع الكلمة الجارية.
  final String? activeSegmentId;

  /// رقم الكلمة الجارية.
  final int? activeTokenIndex;

  /// هل يمكن سماع المتن.
  bool get canPlay =>
      availability == RecitationAvailability.recorded || availability == RecitationAvailability.aligned;

  /// هل يمكن تشغيل مقطع بعينه.
  bool get canPlayChunks => availability == RecitationAvailability.aligned;

  /// نسخة معدلة. تمرير clearActive يمسح الكلمة الجارية.
  RecitationState copyWith({
    RecitationAvailability? availability,
    bool? playing,
    String? activeSegmentId,
    int? activeTokenIndex,
    bool clearActive = false,
  }) {
    return RecitationState(
      availability: availability ?? this.availability,
      playing: playing ?? this.playing,
      reciter: reciter,
      activeSegmentId: clearActive ? null : (activeSegmentId ?? this.activeSegmentId),
      activeTokenIndex: clearActive ? null : (activeTokenIndex ?? this.activeTokenIndex),
    );
  }
}

/// المتحكم لكل حديث.
class RecitationController extends Notifier<RecitationState> {
  RecitationController(this.hadithId);

  /// الحديث.
  final String hadithId;

  AudioSync? _audio;
  RecitationPlayer? _player;
  StreamSubscription<Duration>? _position;
  int _offsetMs = 0;

  @override
  RecitationState build() {
    ref.onDispose(_release);
    final HadithDailyModel? hadith = ref.watch(hadithProvider(hadithId)).value;
    final AudioSync? audio = hadith?.matn.audio;
    _audio = audio;
    final RecitationAvailability availability;
    if (audio == null || audio.assetPath == null || audio.status == AudioStatus.notRecorded) {
      availability = RecitationAvailability.notRecorded;
    } else if (audio.status == AudioStatus.aligned && audio.timings.isNotEmpty) {
      availability = RecitationAvailability.aligned;
    } else {
      availability = RecitationAvailability.recorded;
    }
    return RecitationState(
      availability: availability,
      playing: false,
      reciter: audio?.reciter,
    );
  }

  /// يشغل التلاوة كاملة. يعيد false إن لم تتوفر.
  Future<bool> playAll() async {
    final RecitationPlayer? player = await _ensurePlayer();
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

  /// يشغل مقطع حفظ من أول كلمة إلى آخرها. يتطلب تلاوة متزامنة.
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
    final RecitationPlayer? player = await _ensurePlayer();
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

  /// مدة مقطع الحفظ في التلاوة المتزامنة.
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

  /// يوقف التلاوة.
  Future<void> stop() async {
    await _player?.stop();
    if (ref.mounted) {
      state = state.copyWith(playing: false, clearActive: true);
    }
  }

  Future<RecitationPlayer?> _ensurePlayer() async {
    final AudioSync? audio = _audio;
    final String? asset = audio?.assetPath;
    if (!state.canPlay || asset == null) {
      return null;
    }
    final RecitationPlayer player = _player ??= RecitationPlayer();
    final bool loaded = await player.load(asset);
    if (!ref.mounted) {
      return null;
    }
    if (!loaded) {
      if (ref.mounted) {
        state = state.copyWith(availability: RecitationAvailability.unavailable, playing: false);
      }
      return null;
    }
    _position ??= player.positionStream.listen(_onPosition);
    return player;
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
    _position = null;
    final RecitationPlayer? player = _player;
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
