// إعدادات الخطوط والحجم: حجم خط المتن، وعائلته، وتكبير نصوص الواجهة.
//
// تُحفظ نصاً بصيغة JSON، والقيمة التالفة أو الخارجة عن الحدود تعود إلى
// أقرب قيمة مقبولة بدل أن تكسر الواجهة.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import '../theme/app_typography.dart';
import '../theme/reading_theme.dart';

/// خط المتن.
enum MatnFont {
  /// أميري: نسخ تراثي، وهو الأصل في المتون.
  amiri('amiri', 'أميري', 'نسخ تراثي', AppTypography.amiri),

  /// ريدكس برو: خط حديث واضح للشاشات الصغيرة.
  readex('readex', 'ريدكس', 'حديث واضح', AppTypography.readexPro);

  const MatnFont(this.wire, this.label, this.caption, this.family);

  /// القيمة المخزنة.
  final String wire;

  /// الاسم المعروض.
  final String label;

  /// وصف قصير.
  final String caption;

  /// عائلة الخط المسجلة في pubspec.
  final String family;

  /// يحوّل القيمة المخزنة، والمجهولة تعني أميري.
  static MatnFont fromWire(Object? value) {
    for (final MatnFont font in MatnFont.values) {
      if (font.wire == value) {
        return font;
      }
    }
    return MatnFont.amiri;
  }
}

/// إعدادات القراءة.
@immutable
class ReadingPreferences {
  const ReadingPreferences({
    required this.matnFontSize,
    required this.textScale,
    required this.matnFont,
  });

  /// القيم الافتراضية.
  static const ReadingPreferences defaults = ReadingPreferences(
    matnFontSize: baseMatnFontSize,
    textScale: 1,
    matnFont: MatnFont.amiri,
  );

  /// حجم المتن الأصلي في التصميم.
  static const double baseMatnFontSize = 27;

  /// أصغر حجم للمتن.
  static const double minMatnFontSize = 22;

  /// أكبر حجم للمتن.
  static const double maxMatnFontSize = 38;

  /// أصغر تكبير لنصوص الواجهة.
  static const double minTextScale = 0.9;

  /// أكبر تكبير لنصوص الواجهة.
  static const double maxTextScale = 1.3;

  /// يقرأ الإعدادات من JSON مع ضبط الحدود.
  factory ReadingPreferences.fromJson(Map<String, dynamic> json) {
    final Object? size = json['matnFontSize'];
    final Object? scale = json['textScale'];
    return ReadingPreferences(
      matnFontSize: _clamp(
        size is num ? size.toDouble() : baseMatnFontSize,
        minMatnFontSize,
        maxMatnFontSize,
      ),
      textScale: _clamp(
        scale is num ? scale.toDouble() : 1,
        minTextScale,
        maxTextScale,
      ),
      matnFont: MatnFont.fromWire(json['matnFont']),
    );
  }

  /// حجم خط المتن الرئيسي.
  final double matnFontSize;

  /// تكبير نصوص الواجهة فوق إعداد النظام.
  final double textScale;

  /// عائلة خط المتن.
  final MatnFont matnFont;

  /// امتداد الثيم المقابل.
  ReadingTheme get readingTheme {
    return ReadingTheme(
      matnScale: matnFontSize / baseMatnFontSize,
      matnFamily: matnFont.family,
    );
  }

  /// نسخة معدلة.
  ReadingPreferences copyWith({
    double? matnFontSize,
    double? textScale,
    MatnFont? matnFont,
  }) {
    return ReadingPreferences(
      matnFontSize: _clamp(matnFontSize ?? this.matnFontSize, minMatnFontSize, maxMatnFontSize),
      textScale: _clamp(textScale ?? this.textScale, minTextScale, maxTextScale),
      matnFont: matnFont ?? this.matnFont,
    );
  }

  /// يحوّل الإعدادات إلى JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'matnFontSize': matnFontSize,
      'textScale': textScale,
      'matnFont': matnFont.wire,
    };
  }

  static double _clamp(double value, double min, double max) {
    if (value.isNaN) {
      return min;
    }
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  @override
  bool operator ==(Object other) {
    return other is ReadingPreferences &&
        other.matnFontSize == matnFontSize &&
        other.textScale == textScale &&
        other.matnFont == matnFont;
  }

  @override
  int get hashCode => Object.hash(matnFontSize, textScale, matnFont);
}

/// متحكم إعدادات القراءة.
class ReadingPreferencesController extends Notifier<ReadingPreferences> {
  @override
  ReadingPreferences build() {
    final String? stored = ref.watch(keyValueStoreProvider).readString(StorageKeys.readingPreferences);
    if (stored == null) {
      return ReadingPreferences.defaults;
    }
    try {
      final Object? decoded = jsonDecode(stored);
      if (decoded is Map<String, dynamic>) {
        return ReadingPreferences.fromJson(decoded);
      }
    } on FormatException {
      return ReadingPreferences.defaults;
    }
    return ReadingPreferences.defaults;
  }

  /// يضبط حجم خط المتن.
  void setMatnFontSize(double value) => _save(state.copyWith(matnFontSize: value));

  /// يضبط تكبير نصوص الواجهة.
  void setTextScale(double value) => _save(state.copyWith(textScale: value));

  /// يختار خط المتن.
  void setMatnFont(MatnFont font) => _save(state.copyWith(matnFont: font));

  /// يعيد القيم الافتراضية.
  void reset() => _save(ReadingPreferences.defaults);

  void _save(ReadingPreferences next) {
    if (next == state) {
      return;
    }
    state = next;
    unawaited(
      ref
          .read(keyValueStoreProvider)
          .writeString(StorageKeys.readingPreferences, jsonEncode(next.toJson())),
    );
  }
}

/// إعدادات القراءة الحالية.
final NotifierProvider<ReadingPreferencesController, ReadingPreferences> readingPreferencesProvider =
    NotifierProvider<ReadingPreferencesController, ReadingPreferences>(
  ReadingPreferencesController.new,
);
