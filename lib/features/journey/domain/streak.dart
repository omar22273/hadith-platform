// الاستمرارية: عدد الأيام الوِردية المتتالية التي أُتمّ فيها وِرد واحد على الأقل.
//
// اليوم الوِردي يبدأ عند الفجر لا عند منتصف الليل: من أتمّ وِرده قبيل الفجر
// حُسب لليوم الذي قبله، كما يُحسب الفتح والقفل. والحساب صرف من سجل الإتمام
// المحفوظ، فلا عدّاد مستقل يمكن أن يختل.

import 'package:flutter/foundation.dart';

import 'unlock_schedule.dart';

/// ملخص الاستمرارية.
@immutable
class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.best,
    required this.activeToday,
    required this.lastActiveDay,
  });

  /// لا إتمام بعد.
  static const StreakSummary none = StreakSummary(
    current: 0,
    best: 0,
    activeToday: false,
    lastActiveDay: null,
  );

  /// الأيام المتتالية حتى اليوم (أو حتى الأمس إن لم يُتمّ وِرد اليوم بعد).
  final int current;

  /// أطول سلسلة متتالية في السجل كله.
  final int best;

  /// هل أُتمّ وِرد في اليوم الوِردي الحالي.
  final bool activeToday;

  /// آخر يوم وِردي فيه إتمام.
  final DateTime? lastActiveDay;

  @override
  bool operator ==(Object other) {
    return other is StreakSummary &&
        other.current == current &&
        other.best == best &&
        other.activeToday == activeToday &&
        other.lastActiveDay == lastActiveDay;
  }

  @override
  int get hashCode => Object.hash(current, best, activeToday, lastActiveDay);
}

/// اليوم الوِردي للحظة: تاريخ بداية نافذة الفجر التي وقعت فيها.
DateTime wirdDayOf(DateTime moment, UnlockSchedule schedule) {
  final DateTime start = schedule.currentWindowStart(moment);
  return DateTime(start.year, start.month, start.day);
}

/// يحسب الاستمرارية من أوقات الإتمام.
StreakSummary computeStreak(
  Iterable<DateTime> completions,
  UnlockSchedule schedule,
  DateTime now,
) {
  final Set<DateTime> days = <DateTime>{
    for (final DateTime completedAt in completions)
      if (!completedAt.isAfter(now)) wirdDayOf(completedAt, schedule),
  };
  if (days.isEmpty) {
    return StreakSummary.none;
  }
  final List<DateTime> sorted = days.toList()..sort();
  int best = 1;
  int run = 1;
  for (int i = 1; i < sorted.length; i++) {
    run = _isNextDay(sorted[i - 1], sorted[i]) ? run + 1 : 1;
    if (run > best) {
      best = run;
    }
  }
  final DateTime today = wirdDayOf(now, schedule);
  final DateTime yesterday = DateTime(today.year, today.month, today.day - 1);
  final DateTime last = sorted.last;
  int current = 0;
  if (last == today || last == yesterday) {
    current = 1;
    for (int i = sorted.length - 1; i > 0; i--) {
      if (!_isNextDay(sorted[i - 1], sorted[i])) {
        break;
      }
      current++;
    }
  }
  return StreakSummary(
    current: current,
    best: best,
    activeToday: last == today,
    lastActiveDay: last,
  );
}

bool _isNextDay(DateTime earlier, DateTime later) {
  return DateTime(earlier.year, earlier.month, earlier.day + 1) == later;
}
