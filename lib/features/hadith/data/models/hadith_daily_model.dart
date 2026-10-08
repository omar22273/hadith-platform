// النموذج الجذري للوِرد اليومي.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

import '../../../../core/json/json_reader.dart';
import 'historical_context.dart';
import 'matn.dart';
import 'practice.dart';
import 'provenance.dart';
import 'reflection.dart';
import 'scholar_layer.dart';

/// أساس ربط الحديث بمحطة القافلة.
enum JourneyAssignmentBasis {
  /// ربط موضوعي تعليمي، لا يدّعي أن الحديث قيل في ذلك المكان.
  thematic('thematic'),

  /// ربط تاريخي مُسنَد إلى مصدر.
  historical('historical');

  const JourneyAssignmentBasis(this.wire);

  /// القيمة المخزنة في ملفات JSON.
  final String wire;

  /// يحوّل قيمة JSON إلى عنصر التعداد، ويرمي [JsonParseException] للقيم المجهولة.
  static JourneyAssignmentBasis fromWire(String value) {
    for (final JourneyAssignmentBasis candidate in JourneyAssignmentBasis.values) {
      if (candidate.wire == value) {
        return candidate;
      }
    }
    throw JsonParseException('Unknown JourneyAssignmentBasis value: "$value".');
  }
}

/// الوِرد اليومي: حديث واحد بمراحله الأربع وطبقة طالب العلم وسجل التوثيق.
@immutable
class HadithDailyModel {
  const HadithDailyModel({
    required this.schemaVersion,
    required this.id,
    required this.sequence,
    required this.collection,
    required this.title,
    required this.teaser,
    required this.journey,
    required this.context,
    required this.matn,
    required this.practice,
    required this.reflection,
    required this.scholar,
    required this.provenance,
    required this.review,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory HadithDailyModel.fromJson(JsonMap json) {
    return HadithDailyModel(
      schemaVersion: readString(json, 'schemaVersion'),
      id: readString(json, 'id'),
      sequence: readInt(json, 'sequence'),
      collection: readModel(json, 'collection', CollectionRef.fromJson),
      title: readString(json, 'title'),
      teaser: readModel(json, 'teaser', Teaser.fromJson),
      journey: readModel(json, 'journey', JourneyPlacement.fromJson),
      context: readModel(json, 'context', HistoricalContext.fromJson),
      matn: readModel(json, 'matn', Matn.fromJson),
      practice: readModel(json, 'practice', PracticeConfig.fromJson),
      reflection: readModel(json, 'reflection', Reflection.fromJson),
      scholar: readModel(json, 'scholar', ScholarLayer.fromJson),
      provenance: readModel(json, 'provenance', Provenance.fromJson),
      review: readModel(json, 'review', ReviewInfo.fromJson),
    );
  }

  /// إصدار المخطط.
  final String schemaVersion;

  /// معرّف الحديث، مثل nawawi40_001.
  final String id;

  /// ترتيب الحديث في المنهج.
  final int sequence;

  /// الكتاب الذي ينتمي إليه الحديث في المنهج.
  final CollectionRef collection;

  /// عنوان وصفي قصير.
  final String title;

  /// لمحة التشويق التي تُعرض في ختام وِرد اليوم السابق.
  final Teaser teaser;

  /// موضع الحديث في مسار القوافل.
  final JourneyPlacement journey;

  /// المرحلة الأولى: سياق الورود والحدث التاريخي.
  final HistoricalContext context;

  /// المرحلة الثانية: المتن والبيان اللغوي والتخريج.
  final Matn matn;

  /// المرحلة الثالثة: التثبيت والحفظ التراكمي.
  final PracticeConfig practice;

  /// المرحلة الرابعة: الإسقاط السلوكي.
  final Reflection reflection;

  /// طبقة طالب العلم: الإسناد ومقارنة الروايات.
  final ScholarLayer scholar;

  /// سجل مصدر المتن وكل تعديل طرأ عليه.
  final Provenance provenance;

  /// حالة المراجعة العلمية قبل النشر.
  final ReviewInfo review;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'sequence': sequence,
      'collection': collection.toJson(),
      'title': title,
      'teaser': teaser.toJson(),
      'journey': journey.toJson(),
      'context': context.toJson(),
      'matn': matn.toJson(),
      'practice': practice.toJson(),
      'reflection': reflection.toJson(),
      'scholar': scholar.toJson(),
      'provenance': provenance.toJson(),
      'review': review.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is HadithDailyModel &&
        schemaVersion == other.schemaVersion &&
        id == other.id &&
        sequence == other.sequence &&
        collection == other.collection &&
        title == other.title &&
        teaser == other.teaser &&
        journey == other.journey &&
        context == other.context &&
        matn == other.matn &&
        practice == other.practice &&
        reflection == other.reflection &&
        scholar == other.scholar &&
        provenance == other.provenance &&
        review == other.review;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      schemaVersion,
      id,
      sequence,
      collection,
      title,
      teaser,
      journey,
      context,
      matn,
      practice,
      reflection,
      scholar,
      provenance,
      review,
    ]);
  }
}

/// الكتاب الذي يُدرَّس منه الحديث.
@immutable
class CollectionRef {
  const CollectionRef({
    required this.id,
    required this.title,
    required this.numberInCollection,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory CollectionRef.fromJson(JsonMap json) {
    return CollectionRef(
      id: readString(json, 'id'),
      title: readString(json, 'title'),
      numberInCollection: readInt(json, 'numberInCollection'),
    );
  }

  /// معرّف الكتاب.
  final String id;

  /// عنوان الكتاب.
  final String title;

  /// رقم الحديث في الكتاب.
  final int numberInCollection;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'numberInCollection': numberInCollection,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CollectionRef &&
        id == other.id &&
        title == other.title &&
        numberInCollection == other.numberInCollection;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      id,
      title,
      numberInCollection,
    ]);
  }
}

/// بطاقة التشويق للغد.
@immutable
class Teaser {
  const Teaser({
    required this.text,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory Teaser.fromJson(JsonMap json) {
    return Teaser(
      text: readString(json, 'text'),
    );
  }

  /// نص اللمحة الغامضة.
  final String text;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'text': text,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Teaser &&
        text == other.text;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      text,
    ]);
  }
}

/// موضع الحديث على خريطة الرحلة.
@immutable
class JourneyPlacement {
  const JourneyPlacement({
    required this.stationId,
    required this.stepInStation,
    required this.milestone,
    required this.assignmentBasis,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory JourneyPlacement.fromJson(JsonMap json) {
    return JourneyPlacement(
      stationId: readString(json, 'stationId'),
      stepInStation: readInt(json, 'stepInStation'),
      milestone: readString(json, 'milestone'),
      assignmentBasis: readEnum(json, 'assignmentBasis', JourneyAssignmentBasis.fromWire),
    );
  }

  /// معرّف المحطة في فهرس الرحلة.
  final String stationId;

  /// رقم الخطوة داخل المحطة.
  final int stepInStation;

  /// عنوان الخطوة على الخريطة.
  final String milestone;

  /// أساس الربط بالمحطة.
  final JourneyAssignmentBasis assignmentBasis;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'stationId': stationId,
      'stepInStation': stepInStation,
      'milestone': milestone,
      'assignmentBasis': assignmentBasis.wire,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is JourneyPlacement &&
        stationId == other.stationId &&
        stepInStation == other.stepInStation &&
        milestone == other.milestone &&
        assignmentBasis == other.assignmentBasis;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      stationId,
      stepInStation,
      milestone,
      assignmentBasis,
    ]);
  }
}
