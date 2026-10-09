// تنفيذ مستودع السيرة من أصول التطبيق (Offline-First).

import '../../../core/content/asset_json_source.dart';
import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../domain/seerah_integrity.dart';
import '../domain/seerah_map.dart';
import '../domain/seerah_repository.dart';
import 'models/seerah_station.dart';

/// مسارات ملفات السيرة في الأصول.
abstract final class SeerahPaths {
  /// محطات الرحلة.
  static const String dataset = 'assets/data/seerah_dataset.json';

  /// اليابسة المرسومة.
  static const String land = 'assets/data/seerah_map_land.json';
}

/// المستودع الإنتاجي.
class AssetSeerahRepository implements SeerahRepository {
  const AssetSeerahRepository(this._source);

  final AssetJsonSource _source;

  @override
  Future<SeerahDataset> loadDataset() async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      _source.load(SeerahPaths.dataset),
      _source.load(sourceCatalogAssetPath),
    ]);
    final SeerahDataset dataset = SeerahDataset.fromJson(loaded[0] as Map<String, dynamic>);
    final SourceCatalog sources = SourceCatalog.fromJson(loaded[1] as Map<String, dynamic>);
    final List<String> issues = checkSeerahDataset(dataset, sources: sources);
    if (issues.isNotEmpty) {
      throw SeerahIntegrityException(issues);
    }
    return dataset;
  }

  @override
  Future<SeerahLand> loadLand() async {
    return SeerahLand.fromJson(await _source.load(SeerahPaths.land));
  }
}
