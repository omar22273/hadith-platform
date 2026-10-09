// وتيرة الأوراد: حديث واحد يومياً للمستخدم الجديد، ويُتاح حديثان بعد سبعة
// أيام متتالية، وثلاثة بعد أربعة عشر يوماً.
//
// تُفتح الدرجة بأفضل استمرارية بلغها المستخدم لا بالحالية؛ فانقطاع يوم لا
// يسلبه ما فتحه (بلا عقاب)، والاختيار بين الدرجات المفتوحة له في الإعدادات.
// وتخطي قفل الفجر متاح يدوياً لأغراض التجربة: لنافذة اليوم وحدها، أو دائماً.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/json/json_reader.dart';
import 'streak.dart';
import 'unlock_schedule.dart';

/// درجة وتيرة: عدد الأحاديث يومياً والاستمرارية اللازمة لفتحها.
@immutable
class PaceTier {
  const PaceTier({required this.perDay, required this.requiredStreak});

  /// عدد الأحاديث الجديدة يومياً.
  final int perDay;

  /// الأيام المتتالية اللازمة لفتح الدرجة.
  final int requiredStreak;

  @override
  bool operator ==(Object other) {
    return other is PaceTier && other.perDay == perDay && other.requiredStreak == requiredStreak;
  }

  @override
  int get hashCode => Object.hash(perDay, requiredStreak);
}

/// سياسة الوتيرة.
abstract final class PacePolicy {
  /// الدرجات بترتيبها.
  static const List<PaceTier> tiers = <PaceTier>[
    PaceTier(perDay: 1, requiredStreak: 0),
    PaceTier(perDay: 2, requiredStreak: 7),
    PaceTier(perDay: 3, requiredStreak: 14),
  ];

  /// أعلى حصة مفتوحة لاستمرارية معينة.
  static int maxQuotaFor(int bestStreak) {
    int quota = 1;
    for (final PaceTier tier in tiers) {
      if (bestStreak >= tier.requiredStreak && tier.perDay > quota) {
        quota = tier.perDay;
      }
    }
    return quota;
  }

  /// هل الدرجة مفتوحة.
  static bool isUnlocked(PaceTier tier, int bestStreak) => bestStreak >= tier.requiredStreak;

  /// الدرجة التالية التي لم تُفتح بعد، أو null إن فُتحت كلها.
  static PaceTier? nextTier(int bestStreak) {
    for (final PaceTier tier in tiers) {
      if (tier.requiredStreak > bestStreak) {
        return tier;
      }
    }
    return null;
  }
}

/// إعدادات الوتيرة المحفوظة.
@immutable
class PacingSettings {
  const PacingSettings({
    required this.selectedQuota,
    required this.alwaysBypassLock,
    required this.bypassedWindowStart,
    required this.recordedBestStreak,
  });

  /// إعدادات المستخدم الجديد.
  static const PacingSettings initial = PacingSettings(
    selectedQuota: 1,
    alwaysBypassLock: false,
    bypassedWindowStart: null,
    recordedBestStreak: 0,
  );

  /// يقرأ الإعدادات، والقيم غير الصالحة تعود إلى الافتراضي.
  factory PacingSettings.fromJson(JsonMap json) {
    final Object? quota = json['selectedQuota'];
    final Object? always = json['alwaysBypassLock'];
    final Object? window = json['bypassedWindowStart'];
    final Object? best = json['recordedBestStreak'];
    return PacingSettings(
      selectedQuota: quota is int && quota >= 1 ? quota : 1,
      alwaysBypassLock: always is bool && always,
      bypassedWindowStart: window is String ? DateTime.tryParse(window) : null,
      recordedBestStreak: best is int && best >= 0 ? best : 0,
    );
  }

  /// الحصة اليومية التي اختارها المستخدم (تُقيَّد بالمفتوح له).
  final int selectedQuota;

  /// تخطي قفل الفجر دائماً (وضع التجربة).
  final bool alwaysBypassLock;

  /// بداية النافذة التي تُخطّي قفلها يدوياً لمرة واحدة.
  final DateTime? bypassedWindowStart;

  /// أفضل استمرارية سُجلت، تحفظ الدرجات المفتوحة حتى لو تعذرت قراءة السجل لاحقاً.
  final int recordedBestStreak;

  /// نسخة معدلة.
  PacingSettings copyWith({
    int? selectedQuota,
    bool? alwaysBypassLock,
    DateTime? bypassedWindowStart,
    bool clearBypassedWindow = false,
    int? recordedBestStreak,
  }) {
    return PacingSettings(
      selectedQuota: selectedQuota ?? this.selectedQuota,
      alwaysBypassLock: alwaysBypassLock ?? this.alwaysBypassLock,
      bypassedWindowStart: clearBypassedWindow ? null : bypassedWindowStart ?? this.bypassedWindowStart,
      recordedBestStreak: recordedBestStreak ?? this.recordedBestStreak,
    );
  }

  /// يحوّل الإعدادات إلى JSON.
  JsonMap toJson() {
    return <String, dynamic>{
      'selectedQuota': selectedQuota,
      'alwaysBypassLock': alwaysBypassLock,
      'bypassedWindowStart': bypassedWindowStart?.toIso8601String(),
      'recordedBestStreak': recordedBestStreak,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is PacingSettings &&
        other.selectedQuota == selectedQuota &&
        other.alwaysBypassLock == alwaysBypassLock &&
        other.bypassedWindowStart == bypassedWindowStart &&
        other.recordedBestStreak == recordedBestStreak;
  }

  @override
  int get hashCode {
    return Object.hash(selectedQuota, alwaysBypassLock, bypassedWindowStart, recordedBestStreak);
  }
}

/// حالة الوتيرة المحسوبة في لحظة.
@immutable
class PacingState {
  const PacingState({
    required this.settings,
    required this.streak,
    required this.bestStreak,
    required this.maxUnlockedQuota,
    required this.dailyQuota,
    required this.windowStart,
    required this.nextUnlockAt,
    required this.completedInWindow,
    required this.lockBypassed,
    required this.usesFallbackTime,
  });

  /// يحسب الحالة من الإعدادات وسجل الإتمام وجدول الفتح.
  factory PacingState.compute({
    required PacingSettings settings,
    required Iterable<DateTime> completions,
    required UnlockSchedule schedule,
    required DateTime now,
  }) {
    final List<DateTime> times = completions.toList(growable: false);
    final StreakSummary streak = computeStreak(times, schedule, now);
    final int best = math.max(streak.best, settings.recordedBestStreak);
    final int maxQuota = PacePolicy.maxQuotaFor(best);
    final int quota = math.max(1, math.min(settings.selectedQuota, maxQuota));
    final DateTime windowStart = schedule.currentWindowStart(now);
    int done = 0;
    for (final DateTime completedAt in times) {
      if (!completedAt.isBefore(windowStart) && !completedAt.isAfter(now)) {
        done++;
      }
    }
    final DateTime? bypassed = settings.bypassedWindowStart;
    final DateTime nextUnlockAt = schedule.nextUnlockAfter(now);
    return PacingState(
      settings: settings,
      streak: streak,
      bestStreak: best,
      maxUnlockedQuota: maxQuota,
      dailyQuota: quota,
      windowStart: windowStart,
      nextUnlockAt: nextUnlockAt,
      completedInWindow: done,
      lockBypassed: settings.alwaysBypassLock ||
          (bypassed != null && bypassed.isAtSameMomentAs(windowStart)),
      usesFallbackTime: schedule.usesFallbackOn(nextUnlockAt),
    );
  }

  /// الإعدادات المحفوظة.
  final PacingSettings settings;

  /// الاستمرارية.
  final StreakSummary streak;

  /// أفضل استمرارية (المحسوبة أو المسجلة).
  final int bestStreak;

  /// أعلى حصة مفتوحة.
  final int maxUnlockedQuota;

  /// الحصة اليومية الفعلية.
  final int dailyQuota;

  /// بداية اليوم الوِردي الحالي (فجر اليوم).
  final DateTime windowStart;

  /// وقت فتح الوِرد التالي (فجر الغد).
  final DateTime nextUnlockAt;

  /// الأوراد المكتملة في اليوم الوِردي الحالي.
  final int completedInWindow;

  /// هل تُخطّي القفل لأغراض التجربة.
  final bool lockBypassed;

  /// هل وقت الفتح هو الوقت الاحتياطي في المنهج.
  final bool usesFallbackTime;

  /// الأيام المتتالية (streakDays).
  int get streakDays => streak.current;

  /// هل بلغ المستخدم حصة اليوم.
  bool get quotaReached => completedInWindow >= dailyQuota;

  /// هل فتح الأحاديث الجديدة مقفل حتى الفجر.
  bool get locked => quotaReached && !lockBypassed;

  /// ما بقي من حصة اليوم.
  int get remainingToday => math.max(0, dailyQuota - completedInWindow);

  /// الدرجة التالية التي لم تُفتح.
  PaceTier? get nextTier => PacePolicy.nextTier(bestStreak);

  /// الأيام المتتالية الباقية لفتح الدرجة التالية بمواصلة السلسلة الحالية.
  int? get daysToNextTier {
    final PaceTier? tier = nextTier;
    if (tier == null) {
      return null;
    }
    return math.max(0, tier.requiredStreak - streak.current);
  }

  /// هل الدرجة مفتوحة لهذا المستخدم.
  bool isTierUnlocked(PaceTier tier) => PacePolicy.isUnlocked(tier, bestStreak);

  @override
  bool operator ==(Object other) {
    return other is PacingState &&
        other.settings == settings &&
        other.streak == streak &&
        other.bestStreak == bestStreak &&
        other.maxUnlockedQuota == maxUnlockedQuota &&
        other.dailyQuota == dailyQuota &&
        other.windowStart == windowStart &&
        other.nextUnlockAt == nextUnlockAt &&
        other.completedInWindow == completedInWindow &&
        other.lockBypassed == lockBypassed &&
        other.usesFallbackTime == usesFallbackTime;
  }

  @override
  int get hashCode {
    return Object.hash(
      settings,
      streak,
      bestStreak,
      maxUnlockedQuota,
      dailyQuota,
      windowStart,
      nextUnlockAt,
      completedInWindow,
      lockBypassed,
      usesFallbackTime,
    );
  }
}
