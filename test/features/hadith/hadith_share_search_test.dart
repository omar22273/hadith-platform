// اختبارات مشاركة الحديث وفهرس البحث: المتن المشكول يُنسخ حرفاً بحرف مع
// تخريجه، والبحث يتجاوز التشكيل ويجد بالعنوان والمتن والرقم.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_platform/features/hadith/data/models/models.dart';
import 'package:hadith_platform/features/hadith/domain/hadith_bundle.dart';
import 'package:hadith_platform/features/hadith/domain/hadith_search.dart';
import 'package:hadith_platform/features/hadith/domain/hadith_share_text.dart';

JsonMap _load(String path) => asJsonMap(jsonDecode(File(path).readAsStringSync()), path);

void main() {
  final NarratorCatalog narrators = NarratorCatalog.fromJson(_load('assets/data/catalogs/narrators.json'));
  final SourceCatalog sources = SourceCatalog.fromJson(_load('assets/data/catalogs/sources.json'));
  final CurriculumManifest curriculum =
      CurriculumManifest.fromJson(_load('assets/data/curriculum/nawawi40_curriculum.json'));
  final List<HadithDailyModel> hadiths = <HadithDailyModel>[
    for (final CurriculumItem item in curriculum.items) HadithDailyModel.fromJson(_load(item.assetPath)),
  ];

  test('the share text carries the vocalized matn verbatim and its takhrij', () {
    final HadithDailyModel hadith = hadiths.first;
    final String text = buildHadithShareText(
      HadithBundle(hadith: hadith, narrators: narrators, sources: sources),
    );
    expect(text, contains(hadith.matn.fullText));
    expect(text, contains(hadith.matn.takhrij.displayLabel));
    for (final TakhrijReference reference in hadith.matn.takhrij.references) {
      expect(text, contains(sources.byId(reference.sourceId)?.title ?? reference.sourceId));
    }
  });

  test('search finds by title, by an unvocalized matn word, and by number', () {
    final List<HadithSearchEntry> entries = <HadithSearchEntry>[
      for (int i = 0; i < curriculum.items.length; i++) HadithSearchEntry.of(curriculum.items[i], hadiths[i]),
    ];
    final String firstTitle = curriculum.items.first.title;
    expect(searchHadith(entries, firstTitle).map((HadithSearchEntry e) => e.hadithId), contains(curriculum.items.first.hadithId));
    final String firstWord = hadiths.first.matn.fullText.split(' ').first;
    expect(searchHadith(entries, firstWord), isNotEmpty);
    expect(searchHadith(entries, '${curriculum.items.first.number}'), isNotEmpty);
    expect(searchHadith(entries, 'كلمة لا وجود لها في أي متن'), isEmpty);
    expect(searchHadith(entries, ''), hasLength(entries.length));
  });
}
