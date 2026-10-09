// صيغة ملف النسخة الاحتياطية hadith_backup.json وترميزها وفحص سلامتها.
//
// الملف JSON مقروء: ترويسة (الصيغة والإصدار وتاريخ الإنشاء) ثم خريطة
// «مفتاح التخزين ← قيمته المخزنة كما هي» ثم بصمة SHA-256 تغطي الصيغة والإصدار
// والبيانات معاً. البصمة تكشف التلف ونقص الملف وأي تعديل يدوي، لكنها ليست
// تشفيراً بكلمة سر: لا يحوي الملف إلا تقدماً وتفضيلات، لا بيانات شخصية.
//
// يُستبعد عمداً: ملح التثبيت الخاص بالجهاز، ونسخة التقدم التالف الاحتياطية.

import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/key_value_store.dart';

/// خطأ في ملف النسخة؛ رسالته عربية موجهة للمستخدم.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  /// الوصف.
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// ثوابت الصيغة.
abstract final class BackupFormat {
  /// معرّف الصيغة في الترويسة.
  static const String id = 'hadith-platform-backup';

  /// إصدار الصيغة الذي يكتبه هذا التطبيق ويقرؤه.
  static const int version = 1;

  /// اسم الملف المصدَّر.
  static const String fileName = 'hadith_backup.json';

  /// أكبر حجم يُقبل عند الاستعادة؛ النسخة الفعلية بضعة كيلوبايتات.
  static const int maxBytes = 2 * 1024 * 1024;

  /// المفاتيح التي تدخل النسخة. أي مفتاح غيرها في الملف يُتجاهل عند الاستعادة.
  static const Set<String> includedKeys = <String>{
    StorageKeys.journeyProgress,
    StorageKeys.pacing,
    StorageKeys.seerahVisited,
    StorageKeys.themeMode,
    StorageKeys.readingPreferences,
    StorageKeys.receptionMode,
    StorageKeys.oralPace,
    StorageKeys.reminder,
  };
}

/// محتوى نسخة مقروءة وسليمة.
@immutable
class BackupContents {
  const BackupContents({
    required this.appVersion,
    required this.createdAt,
    required this.entries,
  });

  /// إصدار التطبيق الذي أنشأها.
  final String appVersion;

  /// وقت الإنشاء، أو null إن تعذرت قراءته.
  final DateTime? createdAt;

  /// المفاتيح المسموح بها فقط وقيمها المخزنة.
  final Map<String, String> entries;
}

/// مرمّز الملف.
abstract final class BackupCodec {
  /// يبني نص الملف من القيم المخزنة (يُرشَّح ما خارج [BackupFormat.includedKeys]).
  static String encode(
    Map<String, String> entries, {
    required String appVersion,
    required DateTime createdAt,
  }) {
    final SplayTreeMap<String, String> data = SplayTreeMap<String, String>();
    for (final MapEntry<String, String> entry in entries.entries) {
      if (BackupFormat.includedKeys.contains(entry.key)) {
        data[entry.key] = entry.value;
      }
    }
    final Map<String, Object> document = <String, Object>{
      'format': BackupFormat.id,
      'version': BackupFormat.version,
      'appVersion': appVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'data': data,
      'checksum': checksumOf(data),
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  /// بصمة SHA-256 للبيانات مع معرّف الصيغة وإصدارها.
  static String checksumOf(Map<String, String> data) {
    final String canonical = '${BackupFormat.id}|${BackupFormat.version}|'
        '${jsonEncode(SplayTreeMap<String, String>.from(data))}';
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// يفحص النص ويعيد محتواه، أو يرمي [BackupFormatException] برسالة واضحة.
  static BackupContents decode(String raw) {
    if (raw.length > BackupFormat.maxBytes) {
      throw const BackupFormatException('الملف أكبر من أن يكون نسخة احتياطية لهذا التطبيق.');
    }
    final String text = raw.startsWith('﻿') ? raw.substring(1) : raw;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException('الملف ليس نسخة احتياطية صالحة: تعذرت قراءته أو هو تالف.');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != BackupFormat.id) {
      throw const BackupFormatException('هذا الملف ليس نسخة احتياطية من منصة الحديث النبوي.');
    }
    final Object? version = decoded['version'];
    if (version is! int || version < 1) {
      throw const BackupFormatException('رقم إصدار النسخة غير صالح.');
    }
    if (version > BackupFormat.version) {
      throw const BackupFormatException('النسخة أُنشئت بإصدار أحدث من التطبيق. حدّث التطبيق ثم أعد المحاولة.');
    }
    final Object? data = decoded['data'];
    final Object? checksum = decoded['checksum'];
    if (data is! Map<String, dynamic> || checksum is! String) {
      throw const BackupFormatException('بنية النسخة ناقصة: لا بيانات أو لا بصمة تحقق.');
    }
    final Map<String, String> strings = <String, String>{};
    for (final MapEntry<String, dynamic> entry in data.entries) {
      final Object? value = entry.value;
      if (value is! String) {
        throw const BackupFormatException('بنية النسخة غير صالحة: قيمة مخزنة ليست نصاً.');
      }
      strings[entry.key] = value;
    }
    if (checksumOf(strings) != checksum) {
      throw const BackupFormatException('فشل فحص السلامة: الملف تالف أو عُدّل بعد تصديره.');
    }
    final Object? created = decoded['createdAt'];
    final Object? appVersion = decoded['appVersion'];
    return BackupContents(
      appVersion: appVersion is String ? appVersion : '',
      createdAt: created is String ? DateTime.tryParse(created)?.toLocal() : null,
      entries: Map<String, String>.unmodifiable(<String, String>{
        for (final MapEntry<String, String> entry in strings.entries)
          if (BackupFormat.includedKeys.contains(entry.key)) entry.key: entry.value,
      }),
    );
  }
}
