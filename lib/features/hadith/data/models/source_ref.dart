// الإحالات الموثقة ومراسي الكلمات.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

import '../../../../core/json/json_reader.dart';

/// إحالة موثقة إلى مصدر، مع نص الشاهد حرفياً للتحقق.
@immutable
class SourceRef {
  const SourceRef({
    required this.sourceId,
    required this.locator,
    required this.quote,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory SourceRef.fromJson(JsonMap json) {
    return SourceRef(
      sourceId: readString(json, 'sourceId'),
      locator: readStringOrNull(json, 'locator'),
      quote: readStringOrNull(json, 'quote'),
    );
  }

  /// معرّف المصدر في فهرس المصادر.
  final String sourceId;

  /// موضع الشاهد: الجزء والصفحة أو رقم الحديث.
  final String? locator;

  /// نص الشاهد كما هو في المصدر، يُستعمل في التدقيق الآلي.
  final String? quote;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'locator': locator,
      'quote': quote,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SourceRef &&
        sourceId == other.sourceId &&
        locator == other.locator &&
        quote == other.quote;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      sourceId,
      locator,
      quote,
    ]);
  }
}

/// مرساة تربط بيانات بكلمة أو أكثر من مقطع في المتن.
@immutable
class TokenAnchor {
  const TokenAnchor({
    required this.segmentId,
    required this.tokenIndex,
    required this.length,
    required this.surface,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory TokenAnchor.fromJson(JsonMap json) {
    return TokenAnchor(
      segmentId: readString(json, 'segmentId'),
      tokenIndex: readInt(json, 'tokenIndex'),
      length: readInt(json, 'length'),
      surface: readString(json, 'surface'),
    );
  }

  /// معرّف المقطع.
  final String segmentId;

  /// رقم أول كلمة داخل المقطع (يبدأ من صفر).
  final int tokenIndex;

  /// عدد الكلمات المشمولة.
  final int length;

  /// الكلمات كما في المتن دون علامات الترقيم، للتحقق من سلامة المرساة.
  final String surface;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'segmentId': segmentId,
      'tokenIndex': tokenIndex,
      'length': length,
      'surface': surface,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TokenAnchor &&
        segmentId == other.segmentId &&
        tokenIndex == other.tokenIndex &&
        length == other.length &&
        surface == other.surface;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      segmentId,
      tokenIndex,
      length,
      surface,
    ]);
  }
}
