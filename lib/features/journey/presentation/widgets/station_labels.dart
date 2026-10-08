// نصوص الحالات والأعداد في مسار القوافل.

import '../../../../core/text/arabic_digits.dart';
import '../../domain/journey_snapshot.dart';

/// أسماء ترتيب المراحل.
const List<String> regionOrdinals = <String>[
  'الأولى',
  'الثانية',
  'الثالثة',
  'الرابعة',
  'الخامسة',
  'السادسة',
  'السابعة',
  'الثامنة',
  'التاسعة',
  'العاشرة',
];

/// ترتيب المرحلة بالكلمة.
String regionOrdinal(int index) {
  return index >= 0 && index < regionOrdinals.length
      ? regionOrdinals[index]
      : arabicDigits(index + 1);
}

/// عدد المحطات بصيغته العربية.
String stationCountLabel(int count) {
  if (count == 1) {
    return 'محطة واحدة';
  }
  if (count == 2) {
    return 'محطتان';
  }
  if (count >= 3 && count <= 10) {
    return '${arabicDigits(count)} محطات';
  }
  return '${arabicDigits(count)} محطة';
}

/// أيام المحطة: «اليوم ١» أو «اليوم ١–٢».
String stationDaysLabel(StationView view) {
  final int? first = view.firstDay;
  final int? last = view.lastDay;
  if (first == null || last == null) {
    return 'تُحدَّد أيامها مع المنهج';
  }
  if (first == last) {
    return 'اليوم ${arabicDigits(first)}';
  }
  return 'اليوم ${arabicDigits(first)}–${arabicDigits(last)}';
}

/// سطر حالة المحطة على بطاقتها.
String stationStatusLine(StationView view, TodayKind today) {
  switch (view.status) {
    case StationStatus.completed:
      if (view.isCaravanHere && today == TodayKind.capReached) {
        return 'أتممتَ أورادها · القافلة تنتظر الفجر';
      }
      if (view.isCaravanHere && today == TodayKind.curriculumFinished) {
        return 'اكتملت الأوراد المتاحة';
      }
      return 'مكتملة';
    case StationStatus.active:
      return today == TodayKind.capReached
          ? 'أتممتَ وِرد اليوم · التالي عند الفجر'
          : 'وِرد اليوم بانتظارك';
    case StationStatus.locked:
      switch (view.lockReason) {
        case StationLockReason.awaitingDawn:
          return 'تُفتح عند الفجر';
        case StationLockReason.notInCurriculumYet:
          return 'أورادها قيد الإعداد';
        case StationLockReason.awaitingPrevious:
        case null:
          return 'مقفلة حتى يحين وِردها';
      }
  }
}

/// حالة الوِرد بالكلمة.
String wirdStatusLabel(WirdStatus status) {
  switch (status) {
    case WirdStatus.completed:
      return 'تمّ';
    case WirdStatus.today:
      return 'وِرد اليوم';
    case WirdStatus.afterDawn:
      return 'يُفتح عند الفجر';
    case WirdStatus.upcoming:
      return 'قادم';
  }
}
