// الخطوط: Amiri للمتون والآثار المنقولة، وReadex Pro للواجهات والعناوين.
//
// الخطان من مكتبة Google Fonts (رخصة SIL OFL)، مضمنان في assets/fonts ومسجلان
// في pubspec.yaml بكل أوزانهما، فيعملان دون اتصال، ويختار المحرك ملف الوزن
// الحقيقي (Amiri-Bold مثلاً) بدل تعريض الخط الرقيق آلياً.

import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'reading_theme.dart';

/// أنماط النصوص المشتركة.
abstract final class AppTypography {
  /// عائلة خط المتون.
  static const String amiri = 'Amiri';

  /// عائلة خط الواجهات.
  static const String readexPro = 'ReadexPro';

  /// ارتفاع السطر في المتن الشريف: مسافة رأسية تمنع تداخل الحركات مع الحروف.
  static const double matnLineHeight = 2.35;

  /// المتن الشريف المشكول.
  static TextStyle matn({
    required Color color,
    double fontSize = 27,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: amiri,
      fontSize: fontSize,
      height: matnLineHeight,
      color: color,
      fontWeight: fontWeight,
    );
  }

  /// النصوص المنقولة من المصادر (الشواهد والآثار).
  /// خط المتن بحسب إعدادات القراءة في السياق: يكبّر الحجم بمعامل المستخدم
  /// ويستعمل العائلة التي اختارها. الحجم الممرر هو الحجم عند المعامل 1.
  static TextStyle matnOf(
    BuildContext context, {
    required Color color,
    double fontSize = 27,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final ReadingTheme reading = ReadingTheme.of(context);
    return matn(
      color: color,
      fontSize: fontSize * reading.matnScale,
      fontWeight: fontWeight,
    ).copyWith(fontFamily: reading.matnFamily);
  }

  static TextStyle athar({
    required Color color,
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: amiri,
      fontSize: fontSize,
      height: 1.95,
      color: color,
      fontWeight: fontWeight,
    );
  }

  /// أسماء المحطات والعناوين التراثية.
  static TextStyle heritageTitle({
    required Color color,
    double fontSize = 26,
  }) {
    return TextStyle(
      fontFamily: amiri,
      fontSize: fontSize,
      height: 1.35,
      color: color,
      fontWeight: FontWeight.w700,
    );
  }

  /// نصوص الواجهة.
  static TextStyle ui({
    required Color color,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.7,
  }) {
    return TextStyle(
      fontFamily: readexPro,
      fontSize: fontSize,
      height: height,
      color: color,
      fontWeight: fontWeight,
    );
  }

  /// سلم نصوص الواجهة بخط Readex Pro وألوان اللوحة.
  static TextTheme textTheme(TextTheme base, AppPalette palette) {
    return base.apply(
      fontFamily: readexPro,
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );
  }
}
