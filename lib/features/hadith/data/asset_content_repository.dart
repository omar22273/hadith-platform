// تنفيذ المستودع من أصول التطبيق (Offline-First).

import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/content_repository.dart';
import 'models/models.dart';

/// مسارات ملفات البيانات في الأصول.
abstract final class ContentPaths {
  /// المنهج.
  static const String curriculum = 'assets/data/curriculum/nawawi40_curriculum.json';

  /// مسار القوافل.
  static const String journey = 'assets/data/catalogs/journey_stations.json';

  /// تراجم الرواة.
  static const String narrators = 'assets/data/catalogs/narrators.json';

  /// المصادر.
  static const String sources = 'assets/data/catalogs/sources.json';

  /// بنك العبارات التراثية.
  static const String wisdom = 'assets/data/catalogs/wisdom_bank.json';
}

/// قارئ JSON من حزمة الأصول.
class AssetJsonSource {
  const AssetJsonSource(this._bundle);

  final AssetBundle _bundle;

  /// يقرأ الملف ويحوّله إلى خريطة، ويرمي [JsonParseException] إن لم يكن كائناً.
  Future<JsonMap> load(String path) async {
    final String text = await _bundle.loadString(path);
    return asJsonMap(jsonDecode(text), path);
  }
}

/// المستودع الإنتاجي.
class AssetContentRepository implements ContentRepository {
  const AssetContentRepository(this._source);

  final AssetJsonSource _source;

  @override
  Future<CurriculumManifest> loadCurriculum() async {
    return CurriculumManifest.fromJson(await _source.load(ContentPaths.curriculum));
  }

  @override
  Future<JourneyCatalog> loadJourney() async {
    return JourneyCatalog.fromJson(await _source.load(ContentPaths.journey));
  }

  @override
  Future<NarratorCatalog> loadNarrators() async {
    return NarratorCatalog.fromJson(await _source.load(ContentPaths.narrators));
  }

  @override
  Future<SourceCatalog> loadSources() async {
    return SourceCatalog.fromJson(await _source.load(ContentPaths.sources));
  }

  @override
  Future<WisdomCatalog> loadWisdom() async {
    return WisdomCatalog.fromJson(await _source.load(ContentPaths.wisdom));
  }

  @override
  Future<HadithDailyModel> loadHadith(String hadithId) async {
    final CurriculumManifest curriculum = await loadCurriculum();
    CurriculumItem? item;
    for (final CurriculumItem candidate in curriculum.items) {
      if (candidate.hadithId == hadithId) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      throw UnknownHadithException(hadithId);
    }
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      _source.load(item.assetPath),
      loadNarrators(),
      loadJourney(),
      loadSources(),
    ]);
    final HadithDailyModel hadith = HadithDailyModel.fromJson(loaded[0] as JsonMap);
    final HadithIntegrityChecker checker = HadithIntegrityChecker(
      narrators: loaded[1] as NarratorCatalog,
      journey: loaded[2] as JourneyCatalog,
      sources: loaded[3] as SourceCatalog,
    );
    final List<String> issues = <String>[
      for (final IntegrityIssue issue in checker.check(hadith)) issue.toString(),
      if (hadith.id != item.hadithId)
        'id: الملف يحمل ${hadith.id} والمنهج يشير إلى ${item.hadithId}',
      if (hadith.journey.stationId != item.stationId)
        'journey.stationId: لا يطابق فهرس المنهج ${item.stationId}',
      if (hadith.title != item.title) 'title: لا يطابق فهرس المنهج',
    ];
    if (issues.isNotEmpty) {
      throw ContentIntegrityException(hadithId, issues);
    }
    return hadith;
  }
}
