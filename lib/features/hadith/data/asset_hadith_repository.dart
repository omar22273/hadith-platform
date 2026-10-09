// تنفيذ مستودع الأحاديث من أصول التطبيق (Offline-First).

import '../../../core/content/asset_json_source.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../domain/hadith_repository.dart';
import 'models/models.dart';

/// مسارات ملفات بيانات الحديث في الأصول.
abstract final class HadithPaths {
  /// المنهج.
  static const String curriculum = 'assets/data/curriculum/nawawi40_curriculum.json';

  /// تراجم الرواة.
  static const String narrators = 'assets/data/catalogs/narrators.json';

  /// المصادر (مشتركة مع السيرة).
  static const String sources = sourceCatalogAssetPath;

  /// بنك العبارات التراثية.
  static const String wisdom = 'assets/data/catalogs/wisdom_bank.json';
}

/// المستودع الإنتاجي.
class AssetHadithRepository implements HadithRepository {
  const AssetHadithRepository(this._source);

  final AssetJsonSource _source;

  @override
  Future<CurriculumManifest> loadCurriculum() async {
    return CurriculumManifest.fromJson(await _source.load(HadithPaths.curriculum));
  }

  @override
  Future<NarratorCatalog> loadNarrators() async {
    return NarratorCatalog.fromJson(await _source.load(HadithPaths.narrators));
  }

  @override
  Future<SourceCatalog> loadSources() async {
    return SourceCatalog.fromJson(await _source.load(HadithPaths.sources));
  }

  @override
  Future<WisdomCatalog> loadWisdom() async {
    return WisdomCatalog.fromJson(await _source.load(HadithPaths.wisdom));
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
      loadSources(),
    ]);
    final HadithDailyModel hadith = HadithDailyModel.fromJson(loaded[0] as JsonMap);
    final HadithIntegrityChecker checker = HadithIntegrityChecker(
      narrators: loaded[1] as NarratorCatalog,
      sources: loaded[2] as SourceCatalog,
    );
    final List<String> issues = <String>[
      for (final IntegrityIssue issue in checker.check(hadith)) issue.toString(),
      if (hadith.id != item.hadithId)
        'id: الملف يحمل ${hadith.id} والمنهج يشير إلى ${item.hadithId}',
      if (hadith.collection.numberInCollection != item.number)
        'collection.numberInCollection: لا يطابق رقم المنهج ${item.number}',
      if (hadith.title != item.title) 'title: لا يطابق فهرس المنهج',
    ];
    if (issues.isNotEmpty) {
      throw ContentIntegrityException(hadithId, issues);
    }
    return hadith;
  }
}
