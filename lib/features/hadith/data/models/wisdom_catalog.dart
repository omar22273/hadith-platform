// بنك العبارات التراثية.
//
// Hadith Platform — data model v1.1.0.

import 'package:flutter/foundation.dart';

import '../../../../core/json/json_reader.dart';
import 'source_ref.dart';

/// بنك العبارات التراثية الموثقة لشاشة ختام الوِرد.
@immutable
class WisdomCatalog {
  const WisdomCatalog({
    required this.schemaVersion,
    required this.entries,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory WisdomCatalog.fromJson(JsonMap json) {
    return WisdomCatalog(
      schemaVersion: readString(json, 'schemaVersion'),
      entries: readModelList(json, 'entries', WisdomEntry.fromJson),
    );
  }

  /// إصدار المخطط.
  final String schemaVersion;

  /// العبارات.
  final List<WisdomEntry> entries;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'entries': entries.map((WisdomEntry item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WisdomCatalog &&
        schemaVersion == other.schemaVersion &&
        listEquals(entries, other.entries);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      schemaVersion,
      Object.hashAll(entries),
    ]);
  }
}

/// عبارة تراثية منقولة بنصها عن قائلها.
@immutable
class WisdomEntry {
  const WisdomEntry({
    required this.id,
    required this.text,
    required this.speaker,
    required this.source,
  });

  /// يبني الكائن من خريطة JSON، ويرمي [JsonParseException] عند أي خلل في البنية.
  factory WisdomEntry.fromJson(JsonMap json) {
    return WisdomEntry(
      id: readString(json, 'id'),
      text: readString(json, 'text'),
      speaker: readString(json, 'speaker'),
      source: readModel(json, 'source', SourceRef.fromJson),
    );
  }

  /// المعرّف.
  final String id;

  /// نص العبارة كما في المصدر.
  final String text;

  /// القائل كما سُمّي في المصدر.
  final String speaker;

  /// موضع العبارة، والشاهد كاملاً بإسنادها إلى قائلها.
  final SourceRef source;

  /// يحوّل الكائن إلى خريطة JSON مطابقة للمخطط.
  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'speaker': speaker,
      'source': source.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WisdomEntry &&
        id == other.id &&
        text == other.text &&
        speaker == other.speaker &&
        source == other.source;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      id,
      text,
      speaker,
      source,
    ]);
  }
}
