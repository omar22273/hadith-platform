// إعدادات القراءة داخل الثيم: حجم خط المتن وعائلته، فتقرؤها كل ودجات المتن
// من سياقها دون أن تعرف مصدر التفضيل.

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_typography.dart';

/// امتداد ثيم القراءة.
@immutable
class ReadingTheme extends ThemeExtension<ReadingTheme> {
  const ReadingTheme({required this.matnScale, required this.matnFamily});

  /// القيم الافتراضية: خط أميري بالحجم الأصلي.
  static const ReadingTheme standard = ReadingTheme(
    matnScale: 1,
    matnFamily: AppTypography.amiri,
  );

  /// معامل تكبير خط المتن نسبة إلى الحجم الأصلي (27).
  final double matnScale;

  /// عائلة خط المتن.
  final String matnFamily;

  /// يقرأ الامتداد من الثيم، أو القيم الافتراضية إن لم يوجد.
  static ReadingTheme of(BuildContext context) {
    return Theme.of(context).extension<ReadingTheme>() ?? standard;
  }

  @override
  ReadingTheme copyWith({double? matnScale, String? matnFamily}) {
    return ReadingTheme(
      matnScale: matnScale ?? this.matnScale,
      matnFamily: matnFamily ?? this.matnFamily,
    );
  }

  @override
  ReadingTheme lerp(covariant ThemeExtension<ReadingTheme>? other, double t) {
    if (other is! ReadingTheme) {
      return this;
    }
    return ReadingTheme(
      matnScale: lerpDouble(matnScale, other.matnScale, t) ?? other.matnScale,
      matnFamily: t < 0.5 ? matnFamily : other.matnFamily,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReadingTheme &&
        other.matnScale == matnScale &&
        other.matnFamily == matnFamily;
  }

  @override
  int get hashCode => Object.hash(matnScale, matnFamily);
}
