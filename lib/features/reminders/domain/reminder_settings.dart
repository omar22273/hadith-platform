// إعدادات التذكير اليومي المحفوظة: مفعّل أم لا، ووقت التنبيه (الافتراضي ٧:٠٠
// صباحاً). القيم التالفة أو الخارجة عن المدى تعود إلى الافتراضي.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/text/arabic_digits.dart';

/// إعدادات التذكير.
@immutable
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  /// الافتراضي: معطّل، والوقت ٧:٠٠ صباحاً.
  static const ReminderSettings initial = ReminderSettings(enabled: false, hour: defaultHour, minute: defaultMinute);

  /// ساعة التنبيه الافتراضية.
  static const int defaultHour = 7;

  /// دقيقة التنبيه الافتراضية.
  static const int defaultMinute = 0;

  /// يقرأ الإعدادات من JSON.
  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    final Object? enabled = json['enabled'];
    final Object? hour = json['hour'];
    final Object? minute = json['minute'];
    return ReminderSettings(
      enabled: enabled is bool && enabled,
      hour: hour is int && hour >= 0 && hour <= 23 ? hour : defaultHour,
      minute: minute is int && minute >= 0 && minute <= 59 ? minute : defaultMinute,
    );
  }

  /// يقرأ النص المخزن، والغائب أو التالف يعطي الإعدادات الافتراضية.
  factory ReminderSettings.decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return initial;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ReminderSettings.fromJson(decoded);
      }
    } on FormatException {
      return initial;
    }
    return initial;
  }

  /// هل التذكير مفعّل.
  final bool enabled;

  /// الساعة (٠ إلى ٢٣).
  final int hour;

  /// الدقيقة (٠ إلى ٥٩).
  final int minute;

  /// نسخة معدلة.
  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  /// للتخزين.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'enabled': enabled, 'hour': hour, 'minute': minute};
  }

  /// النص المخزن.
  String encode() => jsonEncode(toJson());

  /// الوقت مكتوباً للعرض، مثل «٧:٠٠ صباحاً».
  String get timeLabel => formatReminderTime(hour, minute);

  @override
  bool operator ==(Object other) {
    return other is ReminderSettings && other.enabled == enabled && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(enabled, hour, minute);
}

/// وقت بنظام الاثنتي عشرة ساعة بالأرقام العربية: «٧:٠٠ صباحاً» و«٩:٣٠ مساءً».
String formatReminderTime(int hour, int minute) {
  final int twelve = hour % 12 == 0 ? 12 : hour % 12;
  final String minutes = minute.toString().padLeft(2, '0');
  final String period = hour < 12 ? 'صباحاً' : 'مساءً';
  return '${arabicDigits(twelve)}:${arabicDigits(minutes)} $period';
}
