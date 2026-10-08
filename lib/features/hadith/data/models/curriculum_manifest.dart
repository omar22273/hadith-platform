// ترتيب الأوراد وسياسة القفل اليومي.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

import '../../../../core/json/json_reader.dart';

/// متى يُفتح وِرد اليوم التالي.
enum UnlockAnchor {
  /// عند دخول وقت الفجر محلياً.
  fajr('fajr');

  const UnlockAnchor(this.wire);

  /// القيمة المخزنة في ملفات JSON.
  final String wire;

  /// يحوّل قيمة JSON إلى عنصر التعداد، ويرمي [JsonParseException] للقيم المجهولة.
  static UnlockAnchor fromWire(String value) {
    for (final UnlockAnchor candidate in UnlockAnchor.values) {
      if (candidate.wire == value) {
        return candidate;
      }
    }
    throw JsonParseException('Unknown UnlockAnchor value: "$value".');
  }
}

/// ترتيب الأوراد وسياسة القفل اليومي.
@immutable
class CurriculumManifest {
  const CurriculumManifest({
    required this.schemaVersion,
    required this.id,
    required this.title,
    required this.dailyCap,
    required this.items,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory CurriculumManifest.fromJson(JsonMap json) {
    return CurriculumManifest(
      schemaVersion: readString(json, 'schemaVersion'),
      id: readString(json, 'id'),
      title: readString(json, 'title'),
      dailyCap: readModel(json, 'dailyCap', DailyCapPolicy.fromJson),
      items: readModelList(json, 'items', CurriculumItem.fromJson),
    );
  }

  /// إصدار المخطط.
  final String schemaVersion;

  /// المعرّف.
  final String id;

  /// العنوان.
  final String title;

  /// قفل الوِرد اليومي.
  final DailyCapPolicy dailyCap;

  /// الأحاديث بالترتيب.
  final List<CurriculumItem> items;

  /// الحديث التالي في المنهج، ومنه تُقرأ بطاقة تشويق الغد.
  CurriculumItem? itemAfter(String hadithId) {
    for (int index = 0; index < items.length - 1; index++) {
      if (items[index].hadithId == hadithId) {
        return items[index + 1];
      }
    }
    return null;
  }

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'title': title,
      'dailyCap': dailyCap.toJson(),
      'items': items.map((CurriculumItem item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CurriculumManifest &&
        schemaVersion == other.schemaVersion &&
        id == other.id &&
        title == other.title &&
        dailyCap == other.dailyCap &&
        listEquals(items, other.items);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      schemaVersion,
      id,
      title,
      dailyCap,
      Object.hashAll(items),
    ]);
  }
}

/// سياسة إغلاق الوِرد اليومي.
@immutable
class DailyCapPolicy {
  const DailyCapPolicy({
    required this.newHadithPerDay,
    required this.unlockAt,
    required this.fallbackLocalTime,
    required this.completionMessage,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory DailyCapPolicy.fromJson(JsonMap json) {
    return DailyCapPolicy(
      newHadithPerDay: readInt(json, 'newHadithPerDay'),
      unlockAt: readEnum(json, 'unlockAt', UnlockAnchor.fromWire),
      fallbackLocalTime: readString(json, 'fallbackLocalTime'),
      completionMessage: readString(json, 'completionMessage'),
    );
  }

  /// عدد الأحاديث الجديدة يومياً.
  final int newHadithPerDay;

  /// وقت فتح الوِرد التالي.
  final UnlockAnchor unlockAt;

  /// وقت بديل HH:MM إن تعذر حساب الفجر.
  final String fallbackLocalTime;

  /// رسالة الإتمام.
  final String completionMessage;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'newHadithPerDay': newHadithPerDay,
      'unlockAt': unlockAt.wire,
      'fallbackLocalTime': fallbackLocalTime,
      'completionMessage': completionMessage,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DailyCapPolicy &&
        newHadithPerDay == other.newHadithPerDay &&
        unlockAt == other.unlockAt &&
        fallbackLocalTime == other.fallbackLocalTime &&
        completionMessage == other.completionMessage;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      newHadithPerDay,
      unlockAt,
      fallbackLocalTime,
      completionMessage,
    ]);
  }
}

/// عنصر في المنهج.
@immutable
class CurriculumItem {
  const CurriculumItem({
    required this.hadithId,
    required this.assetPath,
    required this.stationId,
    required this.title,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory CurriculumItem.fromJson(JsonMap json) {
    return CurriculumItem(
      hadithId: readString(json, 'hadithId'),
      assetPath: readString(json, 'assetPath'),
      stationId: readString(json, 'stationId'),
      title: readString(json, 'title'),
    );
  }

  /// معرّف الحديث.
  final String hadithId;

  /// مسار ملف الحديث في الأصول.
  final String assetPath;

  /// محطة الحديث، فهرس سريع يطابق journey.stationId في ملف الحديث.
  final String stationId;

  /// عنوان الحديث، فهرس سريع يطابق title في ملف الحديث.
  final String title;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'hadithId': hadithId,
      'assetPath': assetPath,
      'stationId': stationId,
      'title': title,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CurriculumItem &&
        hadithId == other.hadithId &&
        assetPath == other.assetPath &&
        stationId == other.stationId &&
        title == other.title;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      hadithId,
      assetPath,
      stationId,
      title,
    ]);
  }
}
