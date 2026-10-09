// نصوص الحالات على مسار الأربعين، في موضع واحد لتتسق العقدة والبطاقة
// وقارئ الشاشة.

import '../../../../core/text/arabic_digits.dart';
import '../../domain/journey_snapshot.dart';

/// عنوان العقدة: عنوان الحديث إن كان مُعدّاً، وإلا «قيد الإعداد».
String wirdTitle(WirdNode node) => node.item?.title ?? 'قيد الإعداد';

/// وسم رقم الحديث.
String wirdNumberLabel(WirdNode node) => 'الحديث ${arabicDigits(node.number)}';

/// سطر الحالة.
String wirdStatusLine(WirdNode node) {
  switch (node.status) {
    case WirdNodeStatus.completed:
      return 'مكتمل';
    case WirdNodeStatus.today:
      return 'وِرد اليوم';
    case WirdNodeStatus.afterDawn:
      return 'يُفتح عند الفجر';
    case WirdNodeStatus.upcoming:
      return 'ينتظر ما قبله';
    case WirdNodeStatus.inPreparation:
      return 'قيد الإعداد والمراجعة';
  }
}

/// وصف العقدة لقارئ الشاشة.
String wirdSemanticLabel(WirdNode node) {
  return '${wirdNumberLabel(node)}: ${wirdTitle(node)}، ${wirdStatusLine(node)}';
}

/// «يوم واحد» و«يومان» و«٣ أيام» و«١١ يوماً».
String daysLabel(int count) {
  if (count == 1) {
    return 'يوم واحد';
  }
  if (count == 2) {
    return 'يومان';
  }
  if (count >= 3 && count <= 10) {
    return '${arabicDigits(count)} أيام';
  }
  return '${arabicDigits(count)} يوماً';
}

/// «حديث واحد» و«حديثان» و«٣ أحاديث».
String hadithCountLabel(int count) {
  if (count == 1) {
    return 'حديث واحد';
  }
  if (count == 2) {
    return 'حديثان';
  }
  if (count >= 3 && count <= 10) {
    return '${arabicDigits(count)} أحاديث';
  }
  return '${arabicDigits(count)} حديثاً';
}
