// التوثيق والتخريج.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

import '../../../../core/json/json_reader.dart';
import 'source_ref.dart';

/// نظام ترقيم الأحاديث في المصدر.
enum NumberingSystem {
  /// ترقيم محمد فؤاد عبد الباقي.
  fuadAbdulBaqi('fuad_abdul_baqi'),

  /// ترقيم موقع sunnah.com.
  sunnahCom('sunnah_com'),

  /// ترقيم آخر يوضَّح في digitalLocator.
  other('other');

  const NumberingSystem(this.wire);

  /// القيمة المخزنة في ملفات JSON.
  final String wire;

  /// يحوّل قيمة JSON إلى عنصر التعداد، ويرمي [JsonParseException] للقيم المجهولة.
  static NumberingSystem fromWire(String value) {
    for (final NumberingSystem candidate in NumberingSystem.values) {
      if (candidate.wire == value) {
        return candidate;
      }
    }
    throw JsonParseException('Unknown NumberingSystem value: "$value".');
  }
}

/// التوثيق الهادئ في زاوية الشاشة والتخريج الإجمالي.
@immutable
class Takhrij {
  const Takhrij({
    required this.displayLabel,
    required this.references,
    required this.compilerStatement,
    required this.gradings,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory Takhrij.fromJson(JsonMap json) {
    return Takhrij(
      displayLabel: readString(json, 'displayLabel'),
      references: readModelList(json, 'references', TakhrijReference.fromJson),
      compilerStatement: readModelOrNull(json, 'compilerStatement', CompilerStatement.fromJson),
      gradings: readModelList(json, 'gradings', Grading.fromJson),
    );
  }

  /// النص المختصر في الزاوية العلوية.
  final String displayLabel;

  /// مواضع الحديث في الكتب.
  final List<TakhrijReference> references;

  /// عبارة المصنف في التخريج كما وردت.
  final CompilerStatement? compilerStatement;

  /// أحكام منقولة عن الأئمة فقط، ولا يُولَّد فيها حكم.
  final List<Grading> gradings;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'displayLabel': displayLabel,
      'references': references.map((TakhrijReference item) => item.toJson()).toList(),
      'compilerStatement': compilerStatement?.toJson(),
      'gradings': gradings.map((Grading item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Takhrij &&
        displayLabel == other.displayLabel &&
        listEquals(references, other.references) &&
        compilerStatement == other.compilerStatement &&
        listEquals(gradings, other.gradings);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      displayLabel,
      Object.hashAll(references),
      compilerStatement,
      Object.hashAll(gradings),
    ]);
  }
}

/// موضع الحديث في كتاب مسند.
@immutable
class TakhrijReference {
  const TakhrijReference({
    required this.sourceId,
    required this.hadithNumber,
    required this.numberingSystem,
    required this.digitalLocator,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory TakhrijReference.fromJson(JsonMap json) {
    return TakhrijReference(
      sourceId: readString(json, 'sourceId'),
      hadithNumber: readString(json, 'hadithNumber'),
      numberingSystem: readEnum(json, 'numberingSystem', NumberingSystem.fromWire),
      digitalLocator: readStringOrNull(json, 'digitalLocator'),
    );
  }

  /// معرّف الكتاب.
  final String sourceId;

  /// رقم الحديث.
  final String hadithNumber;

  /// نظام الترقيم.
  final NumberingSystem numberingSystem;

  /// موضعه في المصدر الرقمي المستخرج منه.
  final String? digitalLocator;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'hadithNumber': hadithNumber,
      'numberingSystem': numberingSystem.wire,
      'digitalLocator': digitalLocator,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TakhrijReference &&
        sourceId == other.sourceId &&
        hadithNumber == other.hadithNumber &&
        numberingSystem == other.numberingSystem &&
        digitalLocator == other.digitalLocator;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      sourceId,
      hadithNumber,
      numberingSystem,
      digitalLocator,
    ]);
  }
}

/// عبارة المصنف في عزو الحديث.
@immutable
class CompilerStatement {
  const CompilerStatement({
    required this.text,
    required this.sourceId,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory CompilerStatement.fromJson(JsonMap json) {
    return CompilerStatement(
      text: readString(json, 'text'),
      sourceId: readString(json, 'sourceId'),
    );
  }

  /// النص كما في المصدر.
  final String text;

  /// معرّف كتاب المصنف.
  final String sourceId;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'text': text,
      'sourceId': sourceId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CompilerStatement &&
        text == other.text &&
        sourceId == other.sourceId;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      text,
      sourceId,
    ]);
  }
}

/// حكم على الحديث منقول بنصه عن إمام.
@immutable
class Grading {
  const Grading({
    required this.grade,
    required this.gradedBy,
    required this.source,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory Grading.fromJson(JsonMap json) {
    return Grading(
      grade: readString(json, 'grade'),
      gradedBy: readString(json, 'gradedBy'),
      source: readModel(json, 'source', SourceRef.fromJson),
    );
  }

  /// نص الحكم.
  final String grade;

  /// صاحب الحكم.
  final String gradedBy;

  /// موضع الحكم.
  final SourceRef source;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'grade': grade,
      'gradedBy': gradedBy,
      'source': source.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Grading &&
        grade == other.grade &&
        gradedBy == other.gradedBy &&
        source == other.source;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      grade,
      gradedBy,
      source,
    ]);
  }
}
