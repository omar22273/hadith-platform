// تسميات رحلة السيرة: العهود والأطوار والمشاهد الثلاثة.

import 'package:flutter/material.dart';

import '../../../../core/text/arabic_digits.dart';
import '../../data/models/seerah_station.dart';

/// اسم العهد.
String covenantLabel(SeerahCovenant covenant) {
  switch (covenant) {
    case SeerahCovenant.preMission:
      return 'ما قبل البعثة';
    case SeerahCovenant.meccan:
      return 'العهد المكي';
    case SeerahCovenant.medinan:
      return 'العهد المدني';
  }
}

/// أيقونة العهد.
IconData covenantIcon(SeerahCovenant covenant) {
  switch (covenant) {
    case SeerahCovenant.preMission:
      return Icons.hourglass_top_rounded;
    case SeerahCovenant.meccan:
      return Icons.landscape_rounded;
    case SeerahCovenant.medinan:
      return Icons.mosque_rounded;
  }
}

/// «الطور ٣ · البعثة والدعوة السرية»؛ فارغ إن كان الطور مجهولاً.
String epochCaption(SeerahEpochInfo? epoch) {
  if (epoch == null) {
    return '';
  }
  return 'الطور ${arabicDigits(epoch.number)} · ${epoch.title}';
}

/// عدد محطات طور بصياغة عربية سليمة.
String stationCountLabel(int count) {
  switch (count) {
    case 0:
      return 'بلا محطات بعد';
    case 1:
      return 'محطة واحدة';
    case 2:
      return 'محطتان';
    default:
      if (count >= 3 && count <= 10) {
        return '${arabicDigits(count)} محطات';
      }
      return '${arabicDigits(count)} محطة';
  }
}

/// عدد الفصول بصياغة عربية سليمة.
String chaptersLabel(int count) {
  switch (count) {
    case 1:
      return 'فصل واحد';
    case 2:
      return 'فصلان';
    default:
      if (count >= 3 && count <= 10) {
        return '${arabicDigits(count)} فصول';
      }
      return '${arabicDigits(count)} فصلاً';
  }
}

/// عدد المقاطع بصياغة عربية سليمة.
String passagesLabel(int count) {
  switch (count) {
    case 1:
      return 'مقطع واحد';
    case 2:
      return 'مقطعان';
    default:
      if (count >= 3 && count <= 10) {
        return '${arabicDigits(count)} مقاطع';
      }
      return '${arabicDigits(count)} مقطعاً';
  }
}

/// عنوان المشهد.
String sceneTitle(SeerahScene scene) {
  switch (scene) {
    case SeerahScene.setting:
      return 'المشهد الزماني';
    case SeerahScene.challenge:
      return 'المأزق والتحدي';
    case SeerahScene.decision:
      return 'القرار والنتيجة النبوية';
  }
}

/// أيقونة المشهد.
IconData sceneIcon(SeerahScene scene) {
  switch (scene) {
    case SeerahScene.setting:
      return Icons.wb_sunny_outlined;
    case SeerahScene.challenge:
      return Icons.help_outline_rounded;
    case SeerahScene.decision:
      return Icons.lightbulb_outline_rounded;
  }
}
