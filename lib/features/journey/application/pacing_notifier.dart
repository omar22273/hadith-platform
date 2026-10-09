// محرك الاستمرارية وضبط وتيرة الأوراد (PacingNotifier).
//
// يحسب streakDays من سجل الإتمام بأيام وِردية تبدأ عند الفجر، ويحفظ في
// SharedPreferences الحصة المختارة وأفضل استمرارية وتخطي القفل للتجربة.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../hadith/application/hadith_providers.dart';
import '../../hadith/data/models/models.dart';
import '../data/pacing_settings_store.dart';
import '../domain/journey_progress.dart';
import '../domain/pacing.dart';
import '../domain/unlock_schedule.dart';
import 'journey_progress_controller.dart';

/// مصدر وقت الفجر؛ يُستبدل حين يُضاف حساب الفجر لموقع المستخدم.
final Provider<FajrTimeSource> fajrTimeSourceProvider = Provider<FajrTimeSource>(
  (Ref ref) => const UnknownFajrTimeSource(),
);

/// متحكم الوتيرة.
class PacingNotifier extends AsyncNotifier<PacingState> {
  late UnlockSchedule _schedule;
  late JourneyProgress _progress;

  @override
  Future<PacingState> build() async {
    ref.watch(nowProvider);
    final CurriculumManifest curriculum = await ref.watch(curriculumProvider.future);
    final JourneyProgress progress = await ref.watch(journeyProgressProvider.future);
    _progress = progress;
    _schedule = UnlockSchedule.fromPolicy(
      curriculum.dailyCap,
      fajrSource: ref.watch(fajrTimeSourceProvider),
    );
    final PacingSettingsStore store = ref.read(pacingSettingsStoreProvider);
    PacingSettings settings = store.read();
    PacingState computed = _compute(settings);
    if (computed.bestStreak > settings.recordedBestStreak) {
      settings = settings.copyWith(recordedBestStreak: computed.bestStreak);
      unawaited(store.write(settings));
      computed = _compute(settings);
    }
    return computed;
  }

  PacingState _compute(PacingSettings settings) {
    return PacingState.compute(
      settings: settings,
      completions: _progress.completionTimes,
      schedule: _schedule,
      now: ref.read(clockProvider)(),
    );
  }

  Future<void> _update(PacingSettings Function(PacingSettings current) change) async {
    final PacingState current = await future;
    final PacingSettings next = change(current.settings);
    if (next == current.settings) {
      return;
    }
    await ref.read(pacingSettingsStoreProvider).write(next);
    if (ref.mounted) {
      state = AsyncData<PacingState>(_compute(next));
    }
  }

  /// يختار الحصة اليومية من الدرجات المفتوحة. يعيد false إن كانت مقفلة.
  Future<bool> selectQuota(int perDay) async {
    final PacingState current = await future;
    if (perDay < 1 || perDay > current.maxUnlockedQuota) {
      return false;
    }
    await _update((PacingSettings settings) => settings.copyWith(selectedQuota: perDay));
    return true;
  }

  /// يتخطى قفل الفجر لليوم الوِردي الحالي وحده (لأغراض التجربة).
  Future<void> bypassTodayLock() async {
    final PacingState current = await future;
    await _update(
      (PacingSettings settings) => settings.copyWith(bypassedWindowStart: current.windowStart),
    );
  }

  /// يفعّل تخطي قفل الفجر دائماً أو يلغيه (وضع التجربة).
  Future<void> setAlwaysBypass(bool enabled) async {
    await _update(
      (PacingSettings settings) => settings.copyWith(
        alwaysBypassLock: enabled,
        clearBypassedWindow: !enabled,
      ),
    );
  }
}

/// حالة الوتيرة.
final AsyncNotifierProvider<PacingNotifier, PacingState> pacingProvider =
    AsyncNotifierProvider<PacingNotifier, PacingState>(PacingNotifier.new);
