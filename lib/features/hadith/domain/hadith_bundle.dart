// حزمة العرض: الحديث مع الفهارس التي يحتاجها لعرض الإسناد والمصادر.

import 'package:flutter/foundation.dart';

import '../../../core/content/citation.dart';
import '../data/models/models.dart';

export '../../../core/content/citation.dart';

/// الحديث وفهارسه.
@immutable
class HadithBundle {
  const HadithBundle({
    required this.hadith,
    required this.narrators,
    required this.sources,
  });

  /// الوِرد.
  final HadithDailyModel hadith;

  /// تراجم الرواة.
  final NarratorCatalog narrators;

  /// المصادر.
  final SourceCatalog sources;

  /// عنوان المصدر، أو معرّفه إن لم يوجد في الفهرس.
  String sourceTitle(String sourceId) => sources.byId(sourceId)?.title ?? sourceId;

  /// إحالة مقروءة إلى الشاهد.
  String citation(SourceRef ref) => formatCitation(sources.byId(ref.sourceId), ref);
}
