// فهرس بحث الأحاديث: عنوان الحديث ورقمه ومتنه المشكول كما في الملف، مطبَّعاً
// للمطابقة فقط. يُعرض في النتائج العنوان والرقم، لا النص المطبَّع.

import 'package:flutter/foundation.dart';

import '../../../core/text/arabic_search.dart';
import '../data/models/models.dart';

/// مدخل في الفهرس.
@immutable
class HadithSearchEntry {
  const HadithSearchEntry({
    required this.hadithId,
    required this.number,
    required this.title,
    required this.matnPreview,
    required this.haystack,
  });

  /// يبني المدخل من حديث وعنصر منهجه.
  factory HadithSearchEntry.of(CurriculumItem item, HadithDailyModel hadith) {
    final String matn = hadith.matn.fullText;
    return HadithSearchEntry(
      hadithId: item.hadithId,
      number: item.number,
      title: item.title,
      matnPreview: matn,
      haystack: '${item.number} ${item.title} ${hadith.teaser.text} $matn',
    );
  }

  /// معرّف الحديث.
  final String hadithId;

  /// رقمه في الكتاب.
  final int number;

  /// عنوانه.
  final String title;

  /// بداية المتن المشكول للعرض.
  final String matnPreview;

  /// النص الذي يُبحث فيه.
  final String haystack;
}

/// يصفّي المدخلات بالكلمات المفتاحية.
List<HadithSearchEntry> searchHadith(List<HadithSearchEntry> entries, String query) {
  return <HadithSearchEntry>[
    for (final HadithSearchEntry entry in entries)
      if (ArabicSearch.matches(entry.haystack, query)) entry,
  ];
}
