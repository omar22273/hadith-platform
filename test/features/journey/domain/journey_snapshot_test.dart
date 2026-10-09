// اختبارات مسار الأربعين: جدول الفتح عند الفجر، والاستمرارية بأيام وِردية،
// ووتيرة الأوراد ودرجاتها، وتخطي القفل للتجربة، ولقطة المسار.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/journey/domain/journey_progress.dart';
import 'package:hadith_platform/features/journey/domain/journey_snapshot.dart';
import 'package:hadith_platform/features/journey/domain/pacing.dart';
import 'package:hadith_platform/features/journey/domain/streak.dart';
import 'package:hadith_platform/features/journey/domain/unlock_schedule.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

void main() {
  final CurriculumManifest curriculum =
      CurriculumManifest.fromJson(_load('assets/data/curriculum/nawawi40_curriculum.json'));
  final UnlockSchedule schedule = UnlockSchedule.fromPolicy(curriculum.dailyCap);

  PacingState pacingAt(
    DateTime now,
    JourneyProgress progress, {
    PacingSettings settings = PacingSettings.initial,
  }) {
    return PacingState.compute(
      settings: settings,
      completions: progress.completionTimes,
      schedule: schedule,
      now: now,
    );
  }

  JourneySnapshot snapshotAt(
    DateTime now,
    JourneyProgress progress, {
    PacingSettings settings = PacingSettings.initial,
  }) {
    return JourneySnapshot.compute(
      curriculum: curriculum,
      progress: progress,
      pacing: pacingAt(now, progress, settings: settings),
      now: now,
    );
  }

  /// سجل إتمام يومي متتالٍ ينتهي مساء [lastDay]، حديثاً واحداً كل مساء.
  JourneyProgress dailyRun(DateTime lastDay, int days) {
    JourneyProgress progress = JourneyProgress.empty;
    for (int i = days - 1; i >= 0; i--) {
      progress = progress.withCompletion(
        'run_${days - i}',
        DateTime(lastDay.year, lastDay.month, lastDay.day - i, 20),
      );
    }
    return progress;
  }

  group('unlock schedule', () {
    test('opens at the fallback dawn time after an evening completion', () {
      expect(schedule.nextUnlockAfter(DateTime(2026, 10, 9, 21)), DateTime(2026, 10, 10, 5));
    });

    test('a completion before dawn opens the same morning', () {
      expect(schedule.nextUnlockAfter(DateTime(2026, 10, 9, 3)), DateTime(2026, 10, 9, 5));
    });

    test('exactly at dawn the next opening is the following day', () {
      expect(schedule.nextUnlockAfter(DateTime(2026, 10, 9, 5)), DateTime(2026, 10, 10, 5));
    });

    test('the current window starts at the last dawn', () {
      expect(schedule.currentWindowStart(DateTime(2026, 10, 9, 4, 59)), DateTime(2026, 10, 8, 5));
      expect(schedule.currentWindowStart(DateTime(2026, 10, 9, 5)), DateTime(2026, 10, 9, 5));
    });

    test('rejects malformed times', () {
      expect(() => LocalTime.parse('24:00'), throwsFormatException);
      expect(LocalTime.parse('05:00'), const LocalTime(5, 0));
    });
  });

  group('streak', () {
    test('no completions means no streak', () {
      expect(computeStreak(const <DateTime>[], schedule, DateTime(2026, 10, 9, 12)), StreakSummary.none);
    });

    test('consecutive wird days count, and a pre-dawn completion belongs to the day before', () {
      final List<DateTime> times = <DateTime>[
        DateTime(2026, 10, 7, 21),
        DateTime(2026, 10, 9, 4, 30),
        DateTime(2026, 10, 9, 22),
      ];
      final StreakSummary streak = computeStreak(times, schedule, DateTime(2026, 10, 9, 23));
      expect(streak.current, 3);
      expect(streak.best, 3);
      expect(streak.activeToday, isTrue);
    });

    test('a streak stays alive until today ends, then breaks without erasing the best', () {
      final List<DateTime> times = <DateTime>[DateTime(2026, 10, 7, 20), DateTime(2026, 10, 8, 20)];
      expect(computeStreak(times, schedule, DateTime(2026, 10, 9, 12)).current, 2);
      final StreakSummary later = computeStreak(times, schedule, DateTime(2026, 10, 10, 12));
      expect(later.current, 0);
      expect(later.best, 2);
    });
  });

  group('pacing', () {
    test('a new user gets one hadith a day', () {
      final PacingState pacing = pacingAt(DateTime(2026, 10, 9, 10), JourneyProgress.empty);
      expect(pacing.dailyQuota, 1);
      expect(pacing.maxUnlockedQuota, 1);
      expect(pacing.streakDays, 0);
      expect(pacing.locked, isFalse);
    });

    test('choosing a locked tier is clamped to the unlocked quota', () {
      final PacingState pacing = pacingAt(
        DateTime(2026, 10, 9, 10),
        JourneyProgress.empty,
        settings: PacingSettings.initial.copyWith(selectedQuota: 3),
      );
      expect(pacing.dailyQuota, 1);
    });

    test('seven consecutive days unlock two a day, fourteen unlock three', () {
      final DateTime now = DateTime(2026, 10, 20, 21);
      final PacingState seven = pacingAt(now, dailyRun(DateTime(2026, 10, 20), 7));
      expect(seven.streakDays, 7);
      expect(seven.maxUnlockedQuota, 2);
      expect(seven.nextTier?.perDay, 3);
      final PacingState fourteen = pacingAt(now, dailyRun(DateTime(2026, 10, 20), 14));
      expect(fourteen.maxUnlockedQuota, 3);
      expect(fourteen.nextTier, isNull);
    });

    test('an unlocked tier stays unlocked after the streak breaks', () {
      final JourneyProgress run = dailyRun(DateTime(2026, 10, 20), 7);
      final PacingState later = pacingAt(
        DateTime(2026, 10, 25, 10),
        run,
        settings: PacingSettings.initial.copyWith(selectedQuota: 2),
      );
      expect(later.streakDays, 0);
      expect(later.bestStreak, 7);
      expect(later.dailyQuota, 2);
    });

    test('a recorded best streak keeps tiers even without history', () {
      final PacingState pacing = pacingAt(
        DateTime(2026, 10, 9, 10),
        JourneyProgress.empty,
        settings: PacingSettings.initial.copyWith(selectedQuota: 3, recordedBestStreak: 14),
      );
      expect(pacing.dailyQuota, 3);
    });

    test('reaching the quota locks until dawn unless bypassed for testing', () {
      final JourneyProgress progress =
          JourneyProgress.empty.withCompletion('nawawi40_001', DateTime(2026, 10, 9, 9));
      final DateTime now = DateTime(2026, 10, 9, 10);
      final PacingState locked = pacingAt(now, progress);
      expect(locked.quotaReached, isTrue);
      expect(locked.locked, isTrue);
      expect(locked.nextUnlockAt, DateTime(2026, 10, 10, 5));
      final PacingState once = pacingAt(
        now,
        progress,
        settings: PacingSettings.initial.copyWith(bypassedWindowStart: locked.windowStart),
      );
      expect(once.locked, isFalse);
      final PacingState nextDay = pacingAt(
        DateTime(2026, 10, 10, 10),
        progress.withCompletion('nawawi40_002', DateTime(2026, 10, 10, 9)),
        settings: PacingSettings.initial.copyWith(bypassedWindowStart: locked.windowStart),
      );
      expect(nextDay.locked, isTrue);
      final PacingState always = pacingAt(
        now,
        progress,
        settings: PacingSettings.initial.copyWith(alwaysBypassLock: true),
      );
      expect(always.locked, isFalse);
    });

    test('settings survive a JSON round trip and tolerate bad values', () {
      final PacingSettings settings = PacingSettings.initial.copyWith(
        selectedQuota: 2,
        alwaysBypassLock: true,
        bypassedWindowStart: DateTime(2026, 10, 9, 5),
        recordedBestStreak: 9,
      );
      expect(PacingSettings.fromJson(settings.toJson()), settings);
      expect(
        PacingSettings.fromJson(const <String, dynamic>{'selectedQuota': -4, 'alwaysBypassLock': 'yes'}),
        PacingSettings.initial,
      );
    });
  });

  group('snapshot', () {
    test('the path draws the whole collection; unprepared hadiths stay in preparation', () {
      final JourneySnapshot snapshot = snapshotAt(DateTime(2026, 10, 9, 10), JourneyProgress.empty);
      expect(snapshot.nodes.length, 42);
      expect(snapshot.segments.length, 5);
      expect(snapshot.segments.first.title, 'العشرة الأولى');
      expect(snapshot.segments.last.title, 'تتمة الأربعين');
      expect(snapshot.nodes[0].status, WirdNodeStatus.today);
      expect(snapshot.nodes[1].status, WirdNodeStatus.upcoming);
      expect(snapshot.nodes[2].status, WirdNodeStatus.inPreparation);
      expect(snapshot.nodes[2].item, isNull);
      expect(snapshot.todayKind, TodayKind.available);
      expect(snapshot.caravanIndex, 0);
    });

    test('finishing today locks the next wird until dawn and the caravan waits', () {
      final JourneyProgress progress =
          JourneyProgress.empty.withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21));
      final JourneySnapshot snapshot = snapshotAt(DateTime(2026, 10, 9, 21, 5), progress);
      expect(snapshot.todayKind, TodayKind.capReached);
      expect(snapshot.nodes[0].status, WirdNodeStatus.completed);
      expect(snapshot.nodes[1].status, WirdNodeStatus.afterDawn);
      expect(snapshot.caravanIndex, 0);
      expect(snapshot.nextUnlockAt, DateTime(2026, 10, 10, 5));
    });

    test('dawn opens the next wird and moves the caravan', () {
      final JourneyProgress progress =
          JourneyProgress.empty.withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21));
      final JourneySnapshot snapshot = snapshotAt(DateTime(2026, 10, 10, 5, 1), progress);
      expect(snapshot.todayKind, TodayKind.available);
      expect(snapshot.nodes[1].status, WirdNodeStatus.today);
      expect(snapshot.caravanIndex, 1);
    });

    test('bypassing the lock for testing opens the next wird at once', () {
      final JourneyProgress progress =
          JourneyProgress.empty.withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21));
      final JourneySnapshot snapshot = snapshotAt(
        DateTime(2026, 10, 9, 21, 5),
        progress,
        settings: PacingSettings.initial.copyWith(alwaysBypassLock: true),
      );
      expect(snapshot.todayKind, TodayKind.available);
      expect(snapshot.nextItem?.hadithId, 'nawawi40_002');
    });

    test('completing every prepared wird finishes this edition of the curriculum', () {
      final JourneyProgress progress = JourneyProgress.empty
          .withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21))
          .withCompletion('nawawi40_002', DateTime(2026, 10, 10, 7));
      final JourneySnapshot snapshot = snapshotAt(DateTime(2026, 10, 10, 7, 5), progress);
      expect(snapshot.todayKind, TodayKind.curriculumFinished);
      expect(snapshot.completedCount, 2);
      expect(snapshot.caravanIndex, 1);
      expect(snapshot.progressFraction, closeTo(2 / 42, 1e-9));
      expect(snapshot.segments.first.completed, 2);
    });
  });

  group('progress', () {
    test('round-trips through JSON and never records a wird twice', () {
      final JourneyProgress progress = JourneyProgress.empty
          .withCompletion('nawawi40_001', DateTime(2026, 10, 9, 21))
          .withCompletion('nawawi40_001', DateTime(2026, 10, 10, 21));
      expect(progress.completed.length, 1);
      expect(JourneyProgress.fromJson(progress.toJson()), progress);
    });
  });
}
