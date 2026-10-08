// المرحلة الرابعة: الإسقاط السلوكي.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

import '../../../../core/json/json_reader.dart';
import 'source_ref.dart';

/// درجة موافقة الخيار لمقصد الحديث (بلا توبيخ).
enum OptionAlignment {
  /// موافق لمقصد الحديث.
  aligned('aligned'),

  /// فيه خير ويحتاج تكميلاً.
  partial('partial'),

  /// بعيد عن مقصد الحديث.
  misaligned('misaligned');

  const OptionAlignment(this.wire);

  /// القيمة المخزنة في ملفات JSON.
  final String wire;

  /// يحوّل قيمة JSON إلى عنصر التعداد، ويرمي [JsonParseException] للقيم المجهولة.
  static OptionAlignment fromWire(String value) {
    for (final OptionAlignment candidate in OptionAlignment.values) {
      if (candidate.wire == value) {
        return candidate;
      }
    }
    throw JsonParseException('Unknown OptionAlignment value: "$value".');
  }
}

/// الإسقاط السلوكي.
@immutable
class Reflection {
  const Reflection({
    required this.scenario,
    required this.impacts,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory Reflection.fromJson(JsonMap json) {
    return Reflection(
      scenario: readModel(json, 'scenario', Scenario.fromJson),
      impacts: readModelList(json, 'impacts', BehavioralImpact.fromJson),
    );
  }

  /// مأزق الموقف الواقعي.
  final Scenario scenario;

  /// الأثر السلوكي في المسار الميسر.
  final List<BehavioralImpact> impacts;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'scenario': scenario.toJson(),
      'impacts': impacts.map((BehavioralImpact item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Reflection &&
        scenario == other.scenario &&
        listEquals(impacts, other.impacts);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      scenario,
      Object.hashAll(impacts),
    ]);
  }
}

/// موقف معاصر بخيارات تقيس فهم المقصد.
@immutable
class Scenario {
  const Scenario({
    required this.situation,
    required this.question,
    required this.options,
    required this.takeaway,
    required this.basis,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory Scenario.fromJson(JsonMap json) {
    return Scenario(
      situation: readString(json, 'situation'),
      question: readString(json, 'question'),
      options: readModelList(json, 'options', ScenarioOption.fromJson),
      takeaway: readString(json, 'takeaway'),
      basis: readModelList(json, 'basis', SourceRef.fromJson),
    );
  }

  /// وصف الموقف.
  final String situation;

  /// السؤال.
  final String question;

  /// الخيارات.
  final List<ScenarioOption> options;

  /// الخلاصة بعد الإجابة.
  final String takeaway;

  /// الشروح التي بُني عليها الموقف.
  final List<SourceRef> basis;

  /// الخيار الموافق لمقصد الحديث.
  ScenarioOption? get alignedOption {
    for (final ScenarioOption option in options) {
      if (option.alignment == OptionAlignment.aligned) {
        return option;
      }
    }
    return null;
  }

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'situation': situation,
      'question': question,
      'options': options.map((ScenarioOption item) => item.toJson()).toList(),
      'takeaway': takeaway,
      'basis': basis.map((SourceRef item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Scenario &&
        situation == other.situation &&
        question == other.question &&
        listEquals(options, other.options) &&
        takeaway == other.takeaway &&
        listEquals(basis, other.basis);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      situation,
      question,
      Object.hashAll(options),
      takeaway,
      Object.hashAll(basis),
    ]);
  }
}

/// خيار مع تغذية راجعة لطيفة.
@immutable
class ScenarioOption {
  const ScenarioOption({
    required this.id,
    required this.text,
    required this.alignment,
    required this.feedback,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory ScenarioOption.fromJson(JsonMap json) {
    return ScenarioOption(
      id: readString(json, 'id'),
      text: readString(json, 'text'),
      alignment: readEnum(json, 'alignment', OptionAlignment.fromWire),
      feedback: readString(json, 'feedback'),
    );
  }

  /// معرّف الخيار.
  final String id;

  /// نص الخيار.
  final String text;

  /// درجة الموافقة.
  final OptionAlignment alignment;

  /// تغذية راجعة بلا توبيخ.
  final String feedback;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'alignment': alignment.wire,
      'feedback': feedback,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ScenarioOption &&
        id == other.id &&
        text == other.text &&
        alignment == other.alignment &&
        feedback == other.feedback;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      id,
      text,
      alignment,
      feedback,
    ]);
  }
}

/// أثر سلوكي مستند إلى شرح معتمد.
@immutable
class BehavioralImpact {
  const BehavioralImpact({
    required this.text,
    required this.sources,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory BehavioralImpact.fromJson(JsonMap json) {
    return BehavioralImpact(
      text: readString(json, 'text'),
      sources: readModelList(json, 'sources', SourceRef.fromJson),
    );
  }

  /// نص الأثر.
  final String text;

  /// المستند.
  final List<SourceRef> sources;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'text': text,
      'sources': sources.map((SourceRef item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BehavioralImpact &&
        text == other.text &&
        listEquals(sources, other.sources);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      text,
      Object.hashAll(sources),
    ]);
  }
}
