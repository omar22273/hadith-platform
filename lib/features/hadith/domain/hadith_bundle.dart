// حزمة العرض: الحديث مع الفهارس التي يحتاجها لعرض الإسناد والمصادر.

import 'package:flutter/foundation.dart';

import '../../../core/text/arabic_digits.dart';
import '../data/models/models.dart';

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

/// يبني إحالة مقروءة: «جامع العلوم والحكم · ج١ ص٧٣» أو «صحيح البخاري · رقم ٣٩٠٦».
String formatCitation(SourceWork? source, SourceRef ref) {
  final String title = source?.title ?? ref.sourceId;
  final String? locator = ref.locator;
  if (locator == null || locator.isEmpty) {
    return title;
  }
  final bool numeric = RegExp(r'^\d+$').hasMatch(locator);
  final String place = numeric ? 'رقم ${arabicDigits(locator)}' : arabicDigits(locator);
  return '$title · $place';
}

/// اسم المؤلف مع العنوان إن لم يكن العنوان دالاً عليه.
String formatSourceByline(SourceWork? source) {
  if (source == null) {
    return '';
  }
  if (source.title.contains(source.author)) {
    return source.title;
  }
  return '${source.author}، ${source.title}';
}
