// تسميات رحلة السيرة: الحقب والمشاهد الثلاثة.

import 'package:flutter/material.dart';

import '../../data/models/seerah_station.dart';

/// اسم الحقبة.
String epochLabel(SeerahEpoch epoch) {
  switch (epoch) {
    case SeerahEpoch.preMission:
      return 'ما قبل البعثة';
    case SeerahEpoch.meccan:
      return 'المرحلة المكية';
    case SeerahEpoch.medinan:
      return 'المرحلة المدنية';
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

/// ترتيب المشهد.
String sceneOrdinal(SeerahScene scene) {
  switch (scene) {
    case SeerahScene.setting:
      return 'المشهد الأول';
    case SeerahScene.challenge:
      return 'المشهد الثاني';
    case SeerahScene.decision:
      return 'المشهد الثالث';
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

/// نص المشهد من المحطة.
String sceneText(SeerahStationModel station, SeerahScene scene) {
  switch (scene) {
    case SeerahScene.setting:
      return station.sceneDescription;
    case SeerahScene.challenge:
      return station.challenge;
    case SeerahScene.decision:
      return station.propheticDecision;
  }
}
