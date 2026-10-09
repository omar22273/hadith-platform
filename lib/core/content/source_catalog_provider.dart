// فهرس المصادر المشترك: يقرؤه الحديث للتحقق والإحالة، وتقرؤه السيرة لعرض
// شواهدها، دون أن تستورد إحدى الميزتين الأخرى.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_json_source.dart';
import 'models/source_catalog.dart';

/// مسار فهرس المصادر في الأصول.
const String sourceCatalogAssetPath = 'assets/data/catalogs/sources.json';

/// فهرس المصادر.
final FutureProvider<SourceCatalog> sourceCatalogProvider = FutureProvider<SourceCatalog>(
  (Ref ref) async {
    final AssetJsonSource source = ref.watch(assetJsonSourceProvider);
    return SourceCatalog.fromJson(await source.load(sourceCatalogAssetPath));
  },
  retry: contentNoRetry,
);
