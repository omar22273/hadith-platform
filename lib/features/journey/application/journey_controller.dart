// متحكم مسار القوافل (AsyncNotifier): يحمّل الفهارس والتقدم، ويحسب اللقطة،
// ويسجل إتمام الأوراد، ويعيد الحساب تلقائياً عند حلول وقت الفتح.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../hadith/application/content_providers.dart';
import '../../hadith/data/models/models.dart';
import '../data/journey_progress_store.dart';
import '../domain/journey_progress.dart';
import '../domain/journey_snapshot.dart';
import '../domain/unlock_schedule.dart';

/// مصدر وقت الفجر؛ الافتراضي يعتمد الوقت الاحتياطي في المنهج.
final Provider<FajrTimeSource> fajrTimeSourceProvider = Provider<FajrTimeSource>(
  (Ref ref) => const UnknownFajrTimeSource(),
);

/// المتحكم.
class JourneyController extends AsyncNotifier<JourneySnapshot> {
  Timer? _unlockTimer;

  @override
  Future<JourneySnapshot> build() async {
    ref.onDispose(() {
      _unlockTimer?.cancel();
    });
    final JourneyCatalog catalog = await ref.watch(journeyCatalogProvider.future);
    final CurriculumManifest curriculum = await ref.watch(curriculumProvider.future);
    final JourneyProgress progress = await ref.read(journeyProgressStoreProvider).read();
    return _compute(catalog, curriculum, progress);
  }

  JourneySnapshot _compute(
    JourneyCatalog catalog,
    CurriculumManifest curriculum,
    JourneyProgress progress,
  ) {
    final DateTime now = ref.read(clockProvider)();
    final UnlockSchedule schedule = UnlockSchedule.fromPolicy(
      curriculum.dailyCap,
      fajrSource: ref.read(fajrTimeSourceProvider),
    );
    final JourneySnapshot snapshot = JourneySnapshot.compute(
      catalog: catalog,
      curriculum: curriculum,
      progress: progress,
      schedule: schedule,
      now: now,
    );
    _armUnlockTimer(snapshot.nextUnlockAt, now);
    return snapshot;
  }

  void _armUnlockTimer(DateTime? unlockAt, DateTime now) {
    _unlockTimer?.cancel();
    _unlockTimer = null;
    if (unlockAt == null) {
      return;
    }
    final Duration wait = unlockAt.difference(now) + const Duration(seconds: 1);
    _unlockTimer = Timer(wait.isNegative ? Duration.zero : wait, refreshClock);
  }

  /// يعيد الحساب بالوقت الحالي (عند حلول الفجر أو عودة التطبيق من الخلفية).
  void refreshClock() {
    if (!ref.mounted) {
      return;
    }
    final JourneySnapshot? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<JourneySnapshot>(
      _compute(current.catalog, current.curriculum, current.progress),
    );
  }

  /// يسجل إتمام وِرد. لا يُسجَّل إلا الوِرد المتاح اليوم، ولا يُكرَّر.
  Future<bool> completeWird(String hadithId) async {
    final JourneySnapshot current = await future;
    final CurriculumItem? next = current.nextItem;
    if (current.todayKind != TodayKind.available || next == null || next.hadithId != hadithId) {
      return false;
    }
    final JourneyProgress updated = current.progress.withCompletion(
      hadithId,
      ref.read(clockProvider)(),
    );
    await ref.read(journeyProgressStoreProvider).write(updated);
    if (!ref.mounted) {
      return true;
    }
    state = AsyncData<JourneySnapshot>(
      _compute(current.catalog, current.curriculum, updated),
    );
    return true;
  }
}

/// لقطة المسار.
final AsyncNotifierProvider<JourneyController, JourneySnapshot> journeyControllerProvider =
    AsyncNotifierProvider<JourneyController, JourneySnapshot>(JourneyController.new);
