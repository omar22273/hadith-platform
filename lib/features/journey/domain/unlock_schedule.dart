// قفل الوِرد اليومي: يُفتح الوِرد الجديد عند الفجر، وعند تعذر حساب الفجر
// يُعتمد الوقت الاحتياطي الوارد في المنهج (fallbackLocalTime).

import 'package:flutter/foundation.dart';

import '../../../core/text/arabic_digits.dart';
import '../../hadith/data/models/models.dart';

/// وقت في اليوم بالساعة والدقيقة.
@immutable
class LocalTime {
  const LocalTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  /// يقرأ صيغة HH:MM.
  factory LocalTime.parse(String value) {
    final RegExpMatch? match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid HH:MM time', value);
    }
    return LocalTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// الساعة.
  final int hour;

  /// الدقيقة.
  final int minute;

  /// هذا الوقت في يوم معين بالتوقيت المحلي.
  DateTime on(DateTime day) => DateTime(day.year, day.month, day.day, hour, minute);

  /// صيغة العرض، مثل «٥:٠٠».
  String format() {
    return '${arabicDigits(hour)}:${arabicDigits(minute.toString().padLeft(2, '0'))}';
  }

  @override
  bool operator ==(Object other) {
    return other is LocalTime && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// مصدر وقت الفجر لليوم.
abstract interface class FajrTimeSource {
  /// وقت الفجر في اليوم المعطى، أو null إن تعذر حسابه.
  LocalTime? fajrOn(DateTime day);
}

/// مصدر لا يعرف وقت الفجر، فيُعتمد الوقت الاحتياطي دائماً.
class UnknownFajrTimeSource implements FajrTimeSource {
  const UnknownFajrTimeSource();

  @override
  LocalTime? fajrOn(DateTime day) => null;
}

/// جدول فتح الأوراد.
@immutable
class UnlockSchedule {
  const UnlockSchedule({
    required this.fallback,
    required this.newHadithPerDay,
    this.fajrSource = const UnknownFajrTimeSource(),
  });

  /// يبني الجدول من سياسة المنهج.
  factory UnlockSchedule.fromPolicy(
    DailyCapPolicy policy, {
    FajrTimeSource fajrSource = const UnknownFajrTimeSource(),
  }) {
    return UnlockSchedule(
      fallback: LocalTime.parse(policy.fallbackLocalTime),
      newHadithPerDay: policy.newHadithPerDay,
      fajrSource: fajrSource,
    );
  }

  /// الوقت الاحتياطي.
  final LocalTime fallback;

  /// عدد الأحاديث الجديدة في اليوم.
  final int newHadithPerDay;

  /// مصدر وقت الفجر.
  final FajrTimeSource fajrSource;

  /// وقت الفتح في يوم معين.
  DateTime unlockOn(DateTime day) => (fajrSource.fajrOn(day) ?? fallback).on(day);

  /// هل يعتمد هذا اليوم على الوقت الاحتياطي.
  bool usesFallbackOn(DateTime day) => fajrSource.fajrOn(day) == null;

  /// أقرب وقت فتح بعد اللحظة المعطاة.
  DateTime nextUnlockAfter(DateTime moment) {
    for (int offset = 0; offset < 3; offset++) {
      final DateTime day = DateTime(moment.year, moment.month, moment.day + offset);
      final DateTime candidate = unlockOn(day);
      if (candidate.isAfter(moment)) {
        return candidate;
      }
    }
    final DateTime fallbackDay = DateTime(moment.year, moment.month, moment.day + 3);
    return unlockOn(fallbackDay);
  }

  /// آخر وقت فتح عند اللحظة المعطاة أو قبلها: بداية «يوم الوِرد» الحالي.
  DateTime currentWindowStart(DateTime moment) {
    for (int offset = 0; offset < 3; offset++) {
      final DateTime day = DateTime(moment.year, moment.month, moment.day - offset);
      final DateTime candidate = unlockOn(day);
      if (!candidate.isAfter(moment)) {
        return candidate;
      }
    }
    final DateTime fallbackDay = DateTime(moment.year, moment.month, moment.day - 3);
    return unlockOn(fallbackDay);
  }

  /// هل بلغ المستخدم حد اليوم، بالنظر إلى أوقات إتمامه.
  bool capReached(Iterable<DateTime> completions, DateTime now) {
    final DateTime windowStart = currentWindowStart(now);
    int count = 0;
    for (final DateTime completedAt in completions) {
      if (!completedAt.isBefore(windowStart) && !completedAt.isAfter(now)) {
        count++;
      }
    }
    return count >= newHadithPerDay;
  }
}
