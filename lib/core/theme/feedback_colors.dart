// ألوان التغذية الراجعة اللحظية (صواب/خطأ) بدرجتين للنهاري والداكن. الأخضر
// يطابق زمرد اللوحة، والأحمر هادئ لا صارخ حتى لا يوبّخ.

import 'package:flutter/material.dart';

/// ألوان التغذية الراجعة.
@immutable
class FeedbackColors {
  const FeedbackColors._({
    required this.rightFill,
    required this.rightBorder,
    required this.rightText,
    required this.wrongFill,
    required this.wrongBorder,
    required this.wrongText,
  });

  static const FeedbackColors _light = FeedbackColors._(
    rightFill: Color(0xFFDCFCE7),
    rightBorder: Color(0xFF16A34A),
    rightText: Color(0xFF166534),
    wrongFill: Color(0xFFFEE2E2),
    wrongBorder: Color(0xFFDC2626),
    wrongText: Color(0xFF991B1B),
  );

  static const FeedbackColors _dark = FeedbackColors._(
    rightFill: Color(0xFF12301F),
    rightBorder: Color(0xFF4ADE80),
    rightText: Color(0xFF86EFAC),
    wrongFill: Color(0xFF3A1A1A),
    wrongBorder: Color(0xFFF87171),
    wrongText: Color(0xFFFCA5A5),
  );

  /// الألوان الموافقة لسمة السياق.
  static FeedbackColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _dark : _light;
  }

  /// خلفية الصواب.
  final Color rightFill;

  /// حد الصواب.
  final Color rightBorder;

  /// نص الصواب.
  final Color rightText;

  /// خلفية الخطأ.
  final Color wrongFill;

  /// حد الخطأ.
  final Color wrongBorder;

  /// نص الخطأ.
  final Color wrongText;
}
