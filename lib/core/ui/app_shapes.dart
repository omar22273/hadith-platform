// حواف Squircle ناعمة من حزمة smooth_corner بنعومة 0.7 (ضمن المدى 0.6 - 0.8).
// لا تُستعمل الحواف المربعة الحادة في أي سطح.

import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';

/// أشكال الأسطح المشتركة.
abstract final class AppShapes {
  /// نعومة الانحناء.
  static const double smoothness = 0.7;

  /// نصف القطر للعناصر الصغيرة كالرقاقات.
  static const double radiusSmall = 14;

  /// نصف القطر للأزرار والبلاطات.
  static const double radiusMedium = 20;

  /// نصف القطر للبطاقات.
  static const double radiusLarge = 28;

  /// نصف القطر لأعلى الأوراق السفلية.
  static const double radiusSheet = 34;

  /// حافة ناعمة بنصف قطر موحد.
  static SmoothRectangleBorder rounded(
    double radius, {
    BorderSide side = BorderSide.none,
  }) {
    return SmoothRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      smoothness: smoothness,
      side: side,
    );
  }

  /// حافة الورقة السفلية: انحناء من الأعلى فقط.
  static SmoothRectangleBorder sheetTop() {
    return SmoothRectangleBorder(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(radiusSheet),
      ),
      smoothness: smoothness,
    );
  }
}
