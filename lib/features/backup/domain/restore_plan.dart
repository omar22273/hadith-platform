// خطة الاستعادة: تُحسب قبل الكتابة وتُعرض على المستخدم ليؤكدها.
//
// القاعدة: التقدم لا يُنقَص أبداً. فالأوراد المنجزة والمحطات المفتوحة تُدمج
// بالاتحاد مع ما في الجهاز (وأقدم وقت إتمام يغلب)، وأفضل استمرارية تأخذ
// الأعلى. أما التفضيلات (السمة والخطوط والتذكير والوتيرة وطريقة التلقي) فتُستبدل
// بما في النسخة. كل قيمة تُفحص بقارئها الحقيقي قبل قبولها، فلا تدخل قيمة
// تالفة إلى التخزين.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/json/json_reader.dart';
import '../../../core/storage/key_value_store.dart';
import '../../journey/domain/journey_progress.dart';
import '../../journey/domain/pacing.dart';
import '../../reminders/domain/reminder_settings.dart';
import 'backup_codec.dart';

/// خطة استعادة جاهزة للتطبيق.
@immutable
class RestorePlan {
  const RestorePlan({
    required this.writes,
    required this.wirdsInBackup,
    required this.wirdsAdded,
    required this.wirdsTotal,
    required this.stationsAdded,
    required this.createdAt,
    required this.appVersion,
  });

  /// القيم التي ستُكتب: مفتاح التخزين ← النص المخزن.
  final Map<String, String> writes;

  /// أوراد منجزة في النسخة.
  final int wirdsInBackup;

  /// أوراد في النسخة ليست مسجلة على الجهاز، ستُضاف.
  final int wirdsAdded;

  /// مجموع الأوراد المنجزة بعد الاستعادة.
  final int wirdsTotal;

  /// محطات سيرة مفتوحة في النسخة ستُضاف.
  final int stationsAdded;

  /// وقت إنشاء النسخة.
  final DateTime? createdAt;

  /// إصدار التطبيق الذي أنشأها.
  final String appVersion;
}

/// يحلل نص التقدم المخزن، والتالف أو الغائب يعطي سجلاً فارغاً.
JourneyProgress parseProgressOrEmpty(String? raw) {
  if (raw == null || raw.isEmpty) {
    return JourneyProgress.empty;
  }
  try {
    return JourneyProgress.fromJson(asJsonMap(jsonDecode(raw), 'journeyProgress'));
  } on FormatException {
    return JourneyProgress.empty;
  } on JsonParseException {
    return JourneyProgress.empty;
  }
}

Set<String> _parseVisited(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const <String>{};
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.whereType<String>().toSet();
    }
  } on FormatException {
    return const <String>{};
  }
  return const <String>{};
}

PacingSettings _parsePacing(String? raw) {
  if (raw == null || raw.isEmpty) {
    return PacingSettings.initial;
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return PacingSettings.fromJson(decoded);
    }
  } on FormatException {
    return PacingSettings.initial;
  }
  return PacingSettings.initial;
}

Never _invalid(String what) {
  throw BackupFormatException('بيانات «$what» في النسخة تالفة، فلم تُطبَّق أي بيانات.');
}

/// يفحص كل قيمة في النسخة ويبني خطة الدمج مع [current] (القيم الحالية في الجهاز).
RestorePlan planRestore(BackupContents backup, Map<String, String> current) {
  final Map<String, String> writes = <String, String>{};
  int wirdsInBackup = 0;
  int wirdsAdded = 0;
  int wirdsTotal = parseProgressOrEmpty(current[StorageKeys.journeyProgress]).completed.length;
  int stationsAdded = 0;

  for (final MapEntry<String, String> entry in backup.entries.entries) {
    final String key = entry.key;
    final String value = entry.value;
    switch (key) {
      case StorageKeys.journeyProgress:
        final JourneyProgress incoming;
        try {
          incoming = JourneyProgress.fromJson(asJsonMap(jsonDecode(value), key));
        } on FormatException {
          _invalid('الأوراد المنجزة');
        } on JsonParseException {
          _invalid('الأوراد المنجزة');
        }
        final JourneyProgress local = parseProgressOrEmpty(current[key]);
        final Map<String, CompletedWird> merged = <String, CompletedWird>{
          for (final CompletedWird wird in local.completed) wird.hadithId: wird,
        };
        wirdsInBackup = incoming.completed.length;
        for (final CompletedWird wird in incoming.completed) {
          final CompletedWird? existing = merged[wird.hadithId];
          if (existing == null) {
            wirdsAdded++;
            merged[wird.hadithId] = wird;
          } else if (wird.completedAt.isBefore(existing.completedAt)) {
            merged[wird.hadithId] = wird;
          }
        }
        final List<CompletedWird> ordered = merged.values.toList()
          ..sort((CompletedWird a, CompletedWird b) {
            final int byTime = a.completedAt.compareTo(b.completedAt);
            return byTime != 0 ? byTime : a.hadithId.compareTo(b.hadithId);
          });
        wirdsTotal = ordered.length;
        writes[key] = jsonEncode(JourneyProgress(completed: ordered).toJson());
      case StorageKeys.seerahVisited:
        final Object? decoded;
        try {
          decoded = jsonDecode(value);
        } on FormatException {
          _invalid('محطات السيرة');
        }
        if (decoded is! List || decoded.any((Object? item) => item is! String)) {
          _invalid('محطات السيرة');
        }
        final Set<String> local = _parseVisited(current[key]);
        final Set<String> union = <String>{...local, ...decoded.cast<String>()};
        stationsAdded = union.length - local.length;
        writes[key] = jsonEncode(union.toList()..sort());
      case StorageKeys.pacing:
        final Object? decoded;
        try {
          decoded = jsonDecode(value);
        } on FormatException {
          _invalid('وتيرة الأوراد');
        }
        if (decoded is! Map<String, dynamic>) {
          _invalid('وتيرة الأوراد');
        }
        final PacingSettings incoming = PacingSettings.fromJson(decoded);
        final PacingSettings local = _parsePacing(current[key]);
        final int best = incoming.recordedBestStreak > local.recordedBestStreak
            ? incoming.recordedBestStreak
            : local.recordedBestStreak;
        writes[key] = jsonEncode(incoming.copyWith(recordedBestStreak: best).toJson());
      case StorageKeys.readingPreferences:
        final Object? decoded;
        try {
          decoded = jsonDecode(value);
        } on FormatException {
          _invalid('الخطوط والحجم');
        }
        if (decoded is! Map<String, dynamic>) {
          _invalid('الخطوط والحجم');
        }
        writes[key] = value;
      case StorageKeys.reminder:
        final Object? decoded;
        try {
          decoded = jsonDecode(value);
        } on FormatException {
          _invalid('التذكير اليومي');
        }
        if (decoded is! Map<String, dynamic>) {
          _invalid('التذكير اليومي');
        }
        writes[key] = ReminderSettings.fromJson(decoded).encode();
      case StorageKeys.themeMode:
      case StorageKeys.receptionMode:
      case StorageKeys.oralPace:
        if (value.isEmpty || value.length > 40) {
          _invalid('التفضيلات');
        }
        writes[key] = value;
    }
  }
  return RestorePlan(
    writes: Map<String, String>.unmodifiable(writes),
    wirdsInBackup: wirdsInBackup,
    wirdsAdded: wirdsAdded,
    wirdsTotal: wirdsTotal,
    stationsAdded: stationsAdded,
    createdAt: backup.createdAt,
    appVersion: backup.appVersion,
  );
}
