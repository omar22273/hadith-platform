// مزودات السنن المهجورة: المستودع، وملفها بعد فحص سلامته، وبطاقاتها مرتبة.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/asset_json_source.dart';
import '../data/asset_sunan_repository.dart';
import '../data/models/sunan.dart';
import '../domain/sunan_repository.dart';

/// المستودع.
final Provider<SunanRepository> sunanRepositoryProvider = Provider<SunanRepository>(
  (Ref ref) => AssetSunanRepository(ref.watch(assetJsonSourceProvider)),
);

/// ملف السنن بعد فحص سلامته.
final FutureProvider<SunanCatalog> sunanCatalogProvider = FutureProvider<SunanCatalog>(
  (Ref ref) => ref.watch(sunanRepositoryProvider).load(),
  retry: contentNoRetry,
);

/// بطاقات السنن بترتيب عرضها؛ فارغة حتى يُحمَّل الملف.
final Provider<List<SunnahItem>> sunanItemsProvider = Provider<List<SunnahItem>>(
  (Ref ref) => ref.watch(sunanCatalogProvider).value?.itemsInOrder ?? const <SunnahItem>[],
);
