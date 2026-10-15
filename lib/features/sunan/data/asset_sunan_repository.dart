// تنفيذ مستودع السنن من أصول التطبيق (Offline-First).

import '../../../core/content/asset_json_source.dart';
import '../../../core/content/models/source_catalog.dart';
import '../../../core/content/source_catalog_provider.dart';
import '../domain/sunan_info.dart';
import '../domain/sunan_integrity.dart';
import '../domain/sunan_repository.dart';
import 'models/sunan.dart';

/// المستودع الإنتاجي.
class AssetSunanRepository implements SunanRepository {
  const AssetSunanRepository(this._source);

  final AssetJsonSource _source;

  @override
  Future<SunanCatalog> load() async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      _source.load(SunanInfo.assetPath),
      _source.load(sourceCatalogAssetPath),
    ]);
    final SunanCatalog catalog = SunanCatalog.fromJson(loaded[0] as Map<String, dynamic>);
    final SourceCatalog sources = SourceCatalog.fromJson(loaded[1] as Map<String, dynamic>);
    final List<String> issues = checkSunanCatalog(catalog, sources: sources);
    if (catalog.id != SunanInfo.id) {
      issues.add('catalog.id: expected "${SunanInfo.id}" but the file carries "${catalog.id}".');
    }
    if (issues.isNotEmpty) {
      throw SunanIntegrityException(issues);
    }
    return catalog;
  }
}
