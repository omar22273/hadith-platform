// تنفيذ مستودع الأذكار من أصول التطبيق (Offline-First).

import '../../../core/content/asset_json_source.dart';
import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../domain/adhkar_category.dart';
import '../domain/adhkar_integrity.dart';
import '../domain/adhkar_repository.dart';
import 'models/adhkar.dart';

/// المستودع الإنتاجي.
class AssetAdhkarRepository implements AdhkarRepository {
  const AssetAdhkarRepository(this._source);

  final AssetJsonSource _source;

  @override
  Future<AdhkarCatalog> loadCategory(AdhkarCategory category) async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      _source.load(category.assetPath),
      _source.load(sourceCatalogAssetPath),
    ]);
    final AdhkarCatalog catalog = AdhkarCatalog.fromJson(loaded[0] as Map<String, dynamic>);
    final SourceCatalog sources = SourceCatalog.fromJson(loaded[1] as Map<String, dynamic>);
    final List<String> issues = checkAdhkarCatalog(catalog, sources: sources);
    if (catalog.id != category.id) {
      issues.add('catalog.id: expected "${category.id}" but the file carries "${catalog.id}".');
    }
    if (issues.isNotEmpty) {
      throw AdhkarIntegrityException(issues);
    }
    return catalog;
  }
}
