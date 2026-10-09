// لوحة ألوان المنصة: ورق دافئ وحبر وقور ولمسات كهرمانية وزمردية للإنجاز.
//
// الوضع النهاري التراثي (Warm Parchment): خلفية كتان عاجي #F8F6F0، وبطاقات
// بيضاء #FFFFFF بحواف خفيفة #E2E8F0، وحبر فحمي #0F172A، ونصوص ثانوية #475569،
// ولمسات كهرمانية وزمردية هادئة.
// الوضع الداكن: خلفية كحلية فاحمة #0F172A وبطاقات #1E293B، بالذهبي #D97706
// والزمردي #059669.
// لا يوجد لون أحمر في اللوحة: المنصة لا تعاقب ولا تنذر.

import 'package:flutter/material.dart';

/// ألوان التصميم مقدمة كامتداد للثيم.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.paper,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.amber,
    required this.amberDeep,
    required this.amberSoft,
    required this.amberText,
    required this.emerald,
    required this.emeraldSoft,
    required this.emeraldText,
    required this.locked,
    required this.lockedSoft,
    required this.onAccent,
    required this.shadow,
    required this.road,
  });

  /// ألوان الوضع النهاري التراثي (Warm Parchment).
  static const AppPalette light = AppPalette(
    paper: Color(0xFFF8F6F0),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2EFE7),
    ink: Color(0xFF0F172A),
    inkSoft: Color(0xFF475569),
    line: Color(0xFFE2E8F0),
    amber: Color(0xFFC27A0E),
    amberDeep: Color(0xFF9A5B0B),
    amberSoft: Color(0xFFFBF1DC),
    amberText: Color(0xFF92400E),
    emerald: Color(0xFF0E8A63),
    emeraldSoft: Color(0xFFE2F3EB),
    emeraldText: Color(0xFF065F46),
    locked: Color(0xFF94A3B8),
    lockedSoft: Color(0xFFEFF1F4),
    onAccent: Color(0xFFFFFFFF),
    shadow: Color(0x330F172A),
    road: Color(0xFFEAE3D2),
  );

  /// ألوان الوضع الداكن.
  static const AppPalette dark = AppPalette(
    paper: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceMuted: Color(0xFF172036),
    ink: Color(0xFFF1EBDD),
    inkSoft: Color(0xFFA9B3C4),
    line: Color(0xFF334155),
    amber: Color(0xFFD97706),
    amberDeep: Color(0xFFB45309),
    amberSoft: Color(0xFF3A2A12),
    amberText: Color(0xFFF2B45E),
    emerald: Color(0xFF059669),
    emeraldSoft: Color(0xFF0F3B30),
    emeraldText: Color(0xFF34D399),
    locked: Color(0xFF64748B),
    lockedSoft: Color(0xFF243044),
    onAccent: Color(0xFFFFFFFF),
    shadow: Color(0x99000000),
    road: Color(0xFF26324A),
  );

  /// خلفية الشاشات.
  final Color paper;

  /// البطاقات والأسطح المرفوعة.
  final Color surface;

  /// الأسطح الهادئة داخل البطاقات.
  final Color surfaceMuted;

  /// الحبر: النصوص الأساسية.
  final Color ink;

  /// النصوص الثانوية.
  final Color inkSoft;

  /// الخطوط الفاصلة والحدود.
  final Color line;

  /// الكهرماني الأساسي للتدرجات والمحطة النشطة.
  final Color amber;

  /// الكهرماني العميق لنهاية التدرج.
  final Color amberDeep;

  /// ظل كهرماني دافئ لتظليل الغريب والخلفيات.
  final Color amberSoft;

  /// كهرماني مقروء للنصوص على الخلفية.
  final Color amberText;

  /// الزمردي للإنجاز.
  final Color emerald;

  /// خلفية زمردية هادئة.
  final Color emeraldSoft;

  /// زمردي مقروء للنصوص.
  final Color emeraldText;

  /// الرمادي الهادئ للمحطات المقفلة.
  final Color locked;

  /// خلفية المحطات المقفلة.
  final Color lockedSoft;

  /// النص فوق الأسطح الملونة.
  final Color onAccent;

  /// لون الظلال.
  final Color shadow;

  /// لون الطريق تحت خط السير.
  final Color road;

  /// التدرج الكهرماني للأزرار والمحطة النشطة.
  LinearGradient get amberGradient {
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: <Color>[amber, amberDeep],
    );
  }

  /// التدرج الزمردي لعلامات الإنجاز.
  LinearGradient get emeraldGradient {
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: <Color>[emerald, Color.lerp(emerald, ink, 0.25) ?? emerald],
    );
  }

  /// يقرأ اللوحة من الثيم الحالي.
  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ?? AppPalette.light;
  }

  @override
  AppPalette copyWith({
    Color? paper,
    Color? surface,
    Color? surfaceMuted,
    Color? ink,
    Color? inkSoft,
    Color? line,
    Color? amber,
    Color? amberDeep,
    Color? amberSoft,
    Color? amberText,
    Color? emerald,
    Color? emeraldSoft,
    Color? emeraldText,
    Color? locked,
    Color? lockedSoft,
    Color? onAccent,
    Color? shadow,
    Color? road,
  }) {
    return AppPalette(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      line: line ?? this.line,
      amber: amber ?? this.amber,
      amberDeep: amberDeep ?? this.amberDeep,
      amberSoft: amberSoft ?? this.amberSoft,
      amberText: amberText ?? this.amberText,
      emerald: emerald ?? this.emerald,
      emeraldSoft: emeraldSoft ?? this.emeraldSoft,
      emeraldText: emeraldText ?? this.emeraldText,
      locked: locked ?? this.locked,
      lockedSoft: lockedSoft ?? this.lockedSoft,
      onAccent: onAccent ?? this.onAccent,
      shadow: shadow ?? this.shadow,
      road: road ?? this.road,
    );
  }

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppPalette(
      paper: mix(paper, other.paper),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      ink: mix(ink, other.ink),
      inkSoft: mix(inkSoft, other.inkSoft),
      line: mix(line, other.line),
      amber: mix(amber, other.amber),
      amberDeep: mix(amberDeep, other.amberDeep),
      amberSoft: mix(amberSoft, other.amberSoft),
      amberText: mix(amberText, other.amberText),
      emerald: mix(emerald, other.emerald),
      emeraldSoft: mix(emeraldSoft, other.emeraldSoft),
      emeraldText: mix(emeraldText, other.emeraldText),
      locked: mix(locked, other.locked),
      lockedSoft: mix(lockedSoft, other.lockedSoft),
      onAccent: mix(onAccent, other.onAccent),
      shadow: mix(shadow, other.shadow),
      road: mix(road, other.road),
    );
  }
}
