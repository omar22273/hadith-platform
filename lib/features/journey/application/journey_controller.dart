// متحكم مسار الأربعين (AsyncNotifier): يجمع المنهج وسجل الإتمام والوتيرة
// في لقطة واحدة، ويسجل إتمام وِرد اليوم، ويقدّم الساعة المرجعية عند حلول
// وقت الفتح فتُعاد الحسابات تلقائياً.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../hadith/application/hadith_providers.dart';
import '../../hadith/data/models/models.dart';
import '../domain/journey_progress.dart';
import '../domain/journey_snapshot.dart';
import '../domain/pacing.dart';
import 'journey_progress_controller.dart';
import 'pacing_notifier.dart';

/// نتيجة محاولة إتمام وِرد.
enum WirdCompletion {
  /// سُجل الوِرد، وبقي من حصة اليوم شيء.
  recorded,

  /// سُجل الوِرد وبلغ المستخدم حصة اليوم.
  quotaReached,

  /// لم يُسجل: ليس وِرد اليوم المتاح.
  rejected,
}

/// المتحكم.
class JourneyController extends AsyncNotifier<JourneySnapshot> {
  @override
  Future<JourneySnapshot> build() async {
    final DateTime now = ref.watch(nowProvider);
    final CurriculumManifest curriculum = await ref.watch(curriculumProvider.future);
    final JourneyProgress progress = await ref.watch(journeyProgressProvider.future);
    final PacingState pacing = await ref.watch(pacingProvider.future);
    final JourneySnapshot snapshot = JourneySnapshot.compute(
      curriculum: curriculum,
      progress: progress,
      pacing: pacing,
      now: now,
    );
    _armUnlockTimer(pacing.nextUnlockAt, now);
    return snapshot;
  }

  void _armUnlockTimer(DateTime unlockAt, DateTime now) {
    final Duration wait = unlockAt.difference(now) + const Duration(seconds: 1);
    final Timer timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (ref.mounted) {
        ref.read(nowProvider.notifier).tick();
      }
    });
    ref.onDispose(timer.cancel);
  }

  /// يعيد الحساب على الوقت الحالي (عند العودة من الخلفية مثلاً).
  void refreshClock() {
    ref.read(nowProvider.notifier).tick();
  }

  /// يسجل إتمام وِرد اليوم. لا يُقبل إلا الوِرد المتاح نفسه.
  Future<WirdCompletion> completeWird(String hadithId) async {
    final JourneySnapshot current = await future;
    final CurriculumItem? next = current.nextItem;
    if (current.todayKind != TodayKind.available || next == null || next.hadithId != hadithId) {
      return WirdCompletion.rejected;
    }
    await ref.read(journeyProgressProvider.notifier).complete(hadithId);
    final PacingState pacing = await ref.read(pacingProvider.future);
    return pacing.quotaReached ? WirdCompletion.quotaReached : WirdCompletion.recorded;
  }
}

/// لقطة المسار.
final AsyncNotifierProvider<JourneyController, JourneySnapshot> journeyControllerProvider =
    AsyncNotifierProvider<JourneyController, JourneySnapshot>(JourneyController.new);
